import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../data/models/app_notification_model.dart';
import '../data/models/messaging_models.dart';
import '../data/models/notification_model.dart';
import '../data/services/messaging_service.dart';
import '../data/services/notification_service.dart';
import '../utils/attendance_capture_helper.dart';
import '../utils/preferences_helper.dart';
import 'employer_notification_controller.dart';
import 'login_controller.dart';

class MessagingController extends GetxController {
  final MessagingService _service = MessagingService();

  final conversations = <ConversationThread>[].obs;
  final unreadTotal = 0.obs;
  /// Tăng khi danh sách nhóm có thông báo tin nhắn đổi (cho bong bóng Obx).
  final unreadNotifTick = 0.obs;
  final messages = <JobChatMessage>[].obs;
  final isLoading = false.obs;
  final isSending = false.obs;
  final isUploading = false.obs;
  final errorMessage = ''.obs;

  final activeThread = Rxn<ConversationThread>();
  final participants = <String, ChatParticipant>{}.obs;
  final replyTo = Rxn<JobChatMessage>();

  bool _inboxBound = false;
  StreamSubscription<List<ConversationThread>>? _inboxSub;
  StreamSubscription<List<ConversationThread>>? _employerOwnedInboxSub;
  List<ConversationThread> _employerMemberInbox = [];
  List<ConversationThread> _employerOwnedInbox = [];
  StreamSubscription<List<JobChatMessage>>? _messagesSub;
  StreamSubscription? _notifUnreadSub;
  StreamSubscription<List<NotificationModel>>? _legacyNotifSub;
  final Set<String> _groupsWithUnreadNotif = {};
  final Map<String, _MessageNotifHint> _inboxMessageHints = {};
  final Map<String, _MessageNotifHint> _legacyMessageHints = {};
  final Map<String, _MessageNotifHint> _unreadMessageHints = {};
  /// Giữ badge tắt sau khi đọc cho tới khi Firestore đồng bộ.
  final Set<String> _optimisticReadGroupIds = {};
  Map<String, int> _readWatermarks = {};

  String get currentUid {
    final id = Get.find<AuthController>().currentUser?.id ?? '';
    if (id.isNotEmpty) return id;
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  int get totalUnreadCount => unreadTotal.value;

  /// Nhóm có thông báo tin chưa đọc (không tính nhóm mute).
  Set<String> get unreadMessageGroupIds =>
      Set<String>.unmodifiable(_groupsWithUnreadNotif);

  /// Số dùng cho chuông + bong bóng (inbox hoặc thông báo, lấy max).
  int get bubbleUnreadCount {
    final notifN = _groupsWithUnreadNotif.length;
    final inboxN = unreadTotal.value;
    return inboxN > notifN ? inboxN : notifN;
  }

  void _syncUnreadTotal() {
    unreadTotal.value = conversations.fold(
      0,
      (sum, t) => t.notificationsMuted ? sum : sum + t.unreadCount,
    );
  }

  Set<String> get mutedGroupIds => conversations
      .where((c) => c.notificationsMuted)
      .map((c) => c.groupId)
      .toSet();

  bool isGroupNotificationsMuted(String groupId) =>
      mutedGroupIds.contains(groupId);

  /// Tin nhắn thuộc nhóm đã tắt thông báo — không tính badge/chuông (user + NTD).
  int visibleUnreadNotificationCount(Iterable<AppNotificationItem> list) {
    final muted = mutedGroupIds;
    return list.where((n) {
      if (n.isRead) return false;
      if (n.category == NotificationCategory.message) {
        final gid = n.messageGroupId ?? '';
        if (gid.isNotEmpty && muted.contains(gid)) return false;
      }
      return true;
    }).length;
  }

  List<AppNotificationItem> visibleNotifications(
    Iterable<AppNotificationItem> list,
  ) {
    final muted = mutedGroupIds;
    return list
        .where(
          (n) =>
              n.category != NotificationCategory.message ||
              !muted.contains(n.messageGroupId ?? ''),
        )
        .toList();
  }

  void _bindNotificationUnreadListener() {
    _notifUnreadSub?.cancel();
    _legacyNotifSub?.cancel();
    final uid = currentUid;
    if (uid.isEmpty) return;

    _notifUnreadSub = NotificationService().streamNotifications().listen(
      (list) {
        _syncInboxMessageHints(list);
        _recomputeUnreadMessageState();
      },
    );

    if (isEmployer) {
      _legacyNotifSub =
          NotificationService().streamByRecipient(uid).listen((list) {
        _syncLegacyMessageHints(list);
        _recomputeUnreadMessageState();
      });
    }
  }

  void _syncInboxMessageHints(List<AppNotificationItem> list) {
    final muted = mutedGroupIds;
    _inboxMessageHints.clear();
    for (final n in list) {
      if (n.isRead) continue;
      if (n.category != NotificationCategory.message) continue;
      final gid = n.messageGroupId ?? '';
      if (gid.isEmpty || muted.contains(gid)) continue;
      _inboxMessageHints[gid] = _hintFromAppNotification(n);
    }
  }

  void _syncLegacyMessageHints(List<NotificationModel> list) {
    final muted = mutedGroupIds;
    _legacyMessageHints.clear();
    for (final n in list) {
      if (n.isRead) continue;
      if (n.type != 'message') continue;
      final gid = (n.data['groupId'] ?? '').toString();
      if (gid.isEmpty || muted.contains(gid)) continue;
      _legacyMessageHints[gid] = _hintFromLegacyNotification(n);
    }
  }

  void _recomputeUnreadMessageState() {
    _mergeUnreadHintsIntoGroups();

    if (conversations.isNotEmpty) {
      _applyInboxFromServer(
        conversations.toList(growable: false),
        skipHintMerge: true,
      );
    } else if (_groupsWithUnreadNotif.isNotEmpty) {
      unreadTotal.value = _groupsWithUnreadNotif.length;
    }
    unreadNotifTick.value++;
  }

  void _mergeUnreadHintsIntoGroups() {
    final muted = mutedGroupIds;
    _groupsWithUnreadNotif.clear();
    _unreadMessageHints.clear();

    void mergeHint(String gid, _MessageNotifHint hint) {
      if (muted.contains(gid)) return;
      _groupsWithUnreadNotif.add(gid);
      final existing = _unreadMessageHints[gid];
      if (existing == null || hint.at.isAfter(existing.at)) {
        _unreadMessageHints[gid] = hint;
      }
    }

    for (final e in _inboxMessageHints.entries) {
      mergeHint(e.key, e.value);
    }
    for (final e in _legacyMessageHints.entries) {
      mergeHint(e.key, e.value);
    }
  }

  _MessageNotifHint _hintFromAppNotification(AppNotificationItem n) {
    final gid = n.messageGroupId ?? '';
    final isGroup = n.data['isGroupChat'] == true;
    final jobTitle = (n.data['groupName'] ?? n.data['jobTitle'] ?? n.title)
        .toString();
    final preview =
        (n.data['preview'] ?? n.body).toString().trim().isNotEmpty
            ? (n.data['preview'] ?? n.body).toString()
            : n.body;
    return _MessageNotifHint(
      groupId: gid,
      title: n.title,
      preview: preview,
      jobTitle: jobTitle,
      isGroupChat: isGroup,
      at: n.createdAt,
    );
  }

  _MessageNotifHint _hintFromLegacyNotification(NotificationModel n) {
    final gid = (n.data['groupId'] ?? '').toString();
    final isGroup =
        n.data['isGroupChat'] == true || n.title.toLowerCase().contains('nhóm');
    var jobTitle = (n.data['groupName'] ?? n.data['jobTitle'] ?? '').toString();
    if (jobTitle.isEmpty && n.title.contains('·')) {
      jobTitle = n.title.split('·').last.trim();
    }
    if (jobTitle.isEmpty) jobTitle = n.title;
    final preview =
        (n.data['preview'] ?? n.body).toString().trim().isNotEmpty
            ? (n.data['preview'] ?? n.body).toString()
            : n.body;
    return _MessageNotifHint(
      groupId: gid,
      title: n.title,
      preview: preview,
      jobTitle: jobTitle,
      isGroupChat: isGroup,
      at: n.createdAt,
    );
  }

  ConversationThread _threadFromHint(_MessageNotifHint hint) {
    return ConversationThread(
      groupId: hint.groupId,
      jobId: '',
      jobTitle: hint.jobTitle,
      employerId: isEmployer ? currentUid : '',
      memberIds: const [],
      lastMessageText: hint.preview,
      lastMessageAt: hint.at,
      peerId: '',
      peerName: hint.preview,
      chatType: hint.isGroupChat ? 'group' : 'direct',
      unreadCount: 1,
    );
  }

  /// Hội thoại chưa đọc mới nhất (cho bong bóng chat nổi).
  ConversationThread? get primaryUnreadThread {
    final unread = conversations
        .where((c) => c.unreadCount > 0 && !c.notificationsMuted)
        .toList(growable: false);
    if (unread.isNotEmpty) {
      unread.sort((a, b) {
        final da = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      return unread.first;
    }

    for (final gid in _groupsWithUnreadNotif) {
      for (final c in conversations) {
        if (c.groupId == gid && !c.notificationsMuted) {
          return c.copyWith(
            unreadCount: c.unreadCount > 0 ? c.unreadCount : 1,
          );
        }
      }
    }

    if (_unreadMessageHints.isEmpty) return null;

    final best = _unreadMessageHints.values.reduce(
      (a, b) => a.at.isAfter(b.at) ? a : b,
    );
    return _threadFromHint(best);
  }

  AuthController get _auth => Get.find<AuthController>();

  String get currentRole =>
      Get.find<AuthController>().currentUser?.role ?? 'candidate';

  bool get isEmployer => currentRole == 'employer';

  @override
  void onClose() {
    _inboxBound = false;
    _inboxSub?.cancel();
    _employerOwnedInboxSub?.cancel();
    _notifUnreadSub?.cancel();
    _legacyNotifSub?.cancel();
    _messagesSub?.cancel();
    activeThread.value = null;
    super.onClose();
  }

  Future<void> loadInbox() async {
    final uid = currentUid;
    if (uid.isEmpty) return;

    isLoading.value = true;
    errorMessage.value = '';
    try {
      await _service.syncChatsFromAcceptedApplications(uid, currentRole);
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _ensureWatermarksLoaded() async {
    final uid = currentUid;
    if (uid.isEmpty) return;
    _readWatermarks = await ChatReadPreferences.getAll(uid);
    if (conversations.isNotEmpty) {
      _applyInboxFromServer(conversations.toList(growable: false));
    }
  }

  void bindInboxStream() {
    final uid = currentUid;
    if (uid.isEmpty || _inboxBound) return;
    _inboxBound = true;

    _inboxSub?.cancel();
    _employerOwnedInboxSub?.cancel();
    _ensureWatermarksLoaded().then((_) {
      _bindNotificationUnreadListener();
      if (isEmployer) {
        _employerMemberInbox = [];
        _employerOwnedInbox = [];
        _inboxSub = _service.streamConversations(uid).listen(
          (list) {
            _employerMemberInbox = list;
            _mergeEmployerInbox();
          },
          onError: (e) => errorMessage.value = e.toString(),
        );
        _employerOwnedInboxSub =
            _service.streamConversationsForEmployer(uid).listen(
          (list) {
            _employerOwnedInbox = list;
            _mergeEmployerInbox();
          },
          onError: (e) => errorMessage.value = e.toString(),
        );
      } else {
        _inboxSub = _service.streamConversations(uid).listen(
          (list) => _applyInboxFromServer(list),
          onError: (e) => errorMessage.value = e.toString(),
        );
      }
    });
  }

  void _mergeEmployerInbox() {
    final map = <String, ConversationThread>{};
    for (final t in _employerMemberInbox) {
      map[t.groupId] = t;
    }
    for (final t in _employerOwnedInbox) {
      map[t.groupId] = t;
    }
    final merged = map.values.toList()
      ..sort((a, b) {
        final da = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    _applyInboxFromServer(merged);
  }

  /// Gọi từ Home để lắng nghe tin nhắn / badge chuông khi chưa mở tab Tin nhắn.
  void ensureInboxListening() {
    if (currentUid.isEmpty) return;
    bindInboxStream();
    loadInbox();
  }

  void _applyInboxFromServer(
    List<ConversationThread> list, {
    bool skipHintMerge = false,
  }) {
    final uid = currentUid;
    final patched = list.map((t) {
      if (t.notificationsMuted) {
        _groupsWithUnreadNotif.remove(t.groupId);
        if (t.unreadCount != 0) {
          return t.copyWith(unreadCount: 0);
        }
        return t;
      }

      var unread = t.unreadCount;

      // Tin mới từ người khác → bỏ trạng thái "đã đọc tạm".
      if (unread > 0 &&
          t.lastSenderId != null &&
          t.lastSenderId!.isNotEmpty &&
          t.lastSenderId != uid) {
        _optimisticReadGroupIds.remove(t.groupId);
      }

      if (_optimisticReadGroupIds.contains(t.groupId)) {
        if (unread == 0) _optimisticReadGroupIds.remove(t.groupId);
        unread = 0;
      } else if (unread == 0 &&
          _groupsWithUnreadNotif.contains(t.groupId) &&
          t.lastSenderId != uid) {
        // Firestore chưa tăng unreadCounts nhưng đã có thông báo tin mới.
        unread = 1;
      }

      return unread == t.unreadCount ? t : t.copyWith(unreadCount: unread);
    }).toList();
    conversations.assignAll(patched);
    if (!skipHintMerge) {
      _syncInboxMessageHintsFromMutedChange();
      _syncLegacyMessageHintsFromMutedChange();
      unreadNotifTick.value++;
    }
    _syncUnreadTotal();
  }

  void _syncInboxMessageHintsFromMutedChange() {
    final muted = mutedGroupIds;
    _inboxMessageHints.removeWhere((gid, _) => muted.contains(gid));
  }

  void _syncLegacyMessageHintsFromMutedChange() {
    final muted = mutedGroupIds;
    _legacyMessageHints.removeWhere((gid, _) => muted.contains(gid));
  }

  Future<void> _persistReadState(String groupId) async {
    final uid = currentUid;
    if (uid.isEmpty || groupId.isEmpty) return;
    final stamp = DateTime.now();
    await ChatReadPreferences.markRead(uid, groupId, stamp);
    _readWatermarks[groupId] = stamp.millisecondsSinceEpoch;
  }

  void _applyLocalRead(String groupId) {
    var changed = false;
    final list = conversations.map((t) {
      if (t.groupId == groupId && t.unreadCount > 0) {
        changed = true;
        return t.copyWith(unreadCount: 0);
      }
      return t;
    }).toList();
    if (changed) {
      conversations.assignAll(list);
      _syncUnreadTotal();
    }
  }

  /// Sau khi tắt thông báo nhóm — xóa badge, bong bóng, thông báo chuông.
  Future<void> dismissNotificationsForMutedGroup(String groupId) async {
    if (groupId.isEmpty) return;
    _groupsWithUnreadNotif.remove(groupId);
    _optimisticReadGroupIds.add(groupId);
    _applyLocalRead(groupId);
    final uid = currentUid;
    if (uid.isEmpty) return;
    try {
      await NotificationService().markMessageNotificationsReadForGroup(
        groupId,
        userId: uid,
      );
      if (isEmployer) {
        await NotificationService().markLegacyMessageNotificationsReadForGroup(
          groupId,
          recipientId: uid,
        );
      }
    } catch (_) {}
    if (Get.isRegistered<EmployerNotificationController>()) {
      Get.find<EmployerNotificationController>().refreshNow();
    }
  }

  Future<void> markConversationRead(String groupId) async {
    final uid = currentUid;
    if (uid.isEmpty || groupId.isEmpty) return;
    _optimisticReadGroupIds.add(groupId);
    _applyLocalRead(groupId);
    await _persistReadState(groupId);
    try {
      await _service.markConversationRead(groupId, uid);
      await NotificationService().markMessageNotificationsReadForGroup(
        groupId,
        userId: uid,
      );
      if (isEmployer) {
        await NotificationService().markLegacyMessageNotificationsReadForGroup(
          groupId,
          recipientId: uid,
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('setState()') || msg.contains('markNeedsBuild()')) {
        return;
      }
      errorMessage.value = msg.replaceFirst('Exception: ', '');
    }
  }

  /// Xóa badge tất cả hội thoại chưa đọc (bong bóng / danh sách).
  Future<void> markAllUnreadConversationsRead() async {
    final uid = currentUid;
    if (uid.isEmpty) return;

    final targets = conversations
        .where((c) => c.unreadCount > 0)
        .map((c) => c.groupId)
        .toList();
    _optimisticReadGroupIds.addAll(targets);
    for (final groupId in targets) {
      _applyLocalRead(groupId);
      await _persistReadState(groupId);
      try {
        await _service.markConversationRead(groupId, uid);
      } catch (_) {
        // Continue marking remaining conversations; local state already updated.
      }
    }
    if (targets.isNotEmpty) {
      await NotificationService().markAllMessageNotificationsRead(userId: uid);
    }
  }

  Future<void> _loadParticipants(ConversationThread thread) async {
    final ids = thread.memberIds.where((id) => id.isNotEmpty).toSet();
    final map = await _service.fetchParticipants(ids);

    final me = _auth.currentUser;
    final uid = currentUid;
    if (me != null && uid.isNotEmpty) {
      final name = '${me.firstName} ${me.lastName}'.trim();
      map[uid] = ChatParticipant(
        uid: uid,
        name: name.isNotEmpty ? name : me.username,
        avatarUrl: me.avatarUrl,
        role: me.role,
      );
    }
    participants.assignAll(map);
  }

  ChatParticipant? participantFor(String senderId) => participants[senderId];

  Future<void> openChat(ConversationThread thread) async {
    activeThread.value = thread;
    messages.clear();
    participants.clear();
    errorMessage.value = '';
    await _loadParticipants(thread);
    _messagesSub?.cancel();
    _messagesSub = _service.streamMessages(thread.groupId).listen(
      (list) {
        messages.assignAll(list);
      },
      onError: (e) {
        errorMessage.value = e.toString();
      },
    );
    Future.microtask(() => markConversationRead(thread.groupId));
  }

  void closeChat() {
    _messagesSub?.cancel();
    _messagesSub = null;
    activeThread.value = null;
    messages.clear();
    participants.clear();
    replyTo.value = null;
  }

  void setReply(JobChatMessage? msg) => replyTo.value = msg;

  void clearReply() => replyTo.value = null;

  String replySenderName(JobChatMessage msg) {
    final p = participantFor(msg.senderId);
    if (p != null && p.name.isNotEmpty) return p.name;
    return 'Thành viên';
  }

  Future<void> toggleReaction(String msgId, String emoji) async {
    final thread = activeThread.value;
    if (thread == null) return;
    await _service.toggleMessageReaction(
      groupId: thread.groupId,
      msgId: msgId,
      emoji: emoji,
    );
  }

  Future<void> deleteMessage(String msgId) async {
    final thread = activeThread.value;
    if (thread == null) return;
    await _service.deleteMessage(groupId: thread.groupId, msgId: msgId);
  }

  Future<void> editMessage(String msgId, String newContent) async {
    final thread = activeThread.value;
    if (thread == null) return;
    await _service.editMessage(
      groupId: thread.groupId,
      msgId: msgId,
      newContent: newContent,
    );
  }

  Future<void> recallMessage(String msgId) async {
    final thread = activeThread.value;
    if (thread == null) return;
    await _service.recallMessage(groupId: thread.groupId, msgId: msgId);
  }

  Future<void> pinMessage(String msgId) async {
    final thread = activeThread.value;
    if (thread == null) return;
    await _service.pinMessage(groupId: thread.groupId, msgId: msgId);
  }

  /// Trả về [msgId, roomUrl] để mở CallScreen.
  Future<({String msgId, String roomUrl})> startCall({
    required bool isVideo,
  }) async {
    final thread = activeThread.value;
    if (thread == null) throw Exception('Chưa mở hội thoại');

    final cleanId = thread.groupId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final roomUrl = 'vl24h_${cleanId}_${isVideo ? 'video' : 'voice'}';
    final msgId = await _service.sendCallMessage(
      groupId: thread.groupId,
      isVideo: isVideo,
      roomUrl: roomUrl,
    );
    return (msgId: msgId, roomUrl: roomUrl);
  }

  Future<void> endCall(String msgId) async {
    final thread = activeThread.value;
    if (thread == null) return;
    await _service.updateCallStatus(
      groupId: thread.groupId,
      msgId: msgId,
      status: 'ended',
    );
  }

  Future<void> openChatByGroupId(String groupId) async {
    if (groupId.isEmpty) return;
    errorMessage.value = '';

    if (!_inboxBound) {
      ensureInboxListening();
    }

    ConversationThread? thread;
    for (final c in conversations) {
      if (c.groupId == groupId) {
        thread = c;
        break;
      }
    }

    if (thread == null) {
      try {
        thread = await _service.getThread(groupId, currentUid);
      } catch (e) {
        errorMessage.value =
            'Không tải được cuộc trò chuyện. Vui lòng thử lại.';
        return;
      }
    }

    if (thread == null) {
      errorMessage.value =
          'Không tìm thấy nhóm chat hoặc bạn không còn trong nhóm này.';
      return;
    }

    try {
      await openChat(thread);
    } catch (e) {
      activeThread.value = null;
      errorMessage.value =
          e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> sendText(String text) async {
    final thread = activeThread.value;
    if (thread == null) return;

    Map<String, dynamic>? replyMeta;
    final reply = replyTo.value;
    if (reply != null) {
      replyMeta = {
        'msgId': reply.msgId,
        'senderId': reply.senderId,
        'senderName': replySenderName(reply),
        'content': reply.content,
        'type': reply.type,
      };
    }

    isSending.value = true;
    try {
      await _service.sendText(thread.groupId, text, replyTo: replyMeta);
      clearReply();
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isSending.value = false;
    }
  }

  String? get _attendanceCandidateId {
    final thread = activeThread.value;
    if (thread == null) return null;
    return thread.attendanceCandidateId(currentUid, currentRole);
  }

  Future<void> checkIn() async {
    final thread = activeThread.value;
    if (thread != null && !thread.isGroupChat) {
      throw Exception('Điểm danh chỉ dùng trong nhóm chat ca làm');
    }
    final candidateId = _attendanceCandidateId;
    if (thread == null || candidateId == null) {
      throw Exception(
        isEmployer
            ? 'Chỉ ứng viên mới điểm danh đầu ca'
            : 'Bạn không thể điểm danh trong hội thoại này',
      );
    }

    isSending.value = true;
    try {
      await _service.checkInShift(
        groupId: thread.groupId,
        jobId: thread.jobId,
        employerId: thread.employerId,
        candidateId: candidateId,
      );
    } finally {
      isSending.value = false;
    }
  }

  Future<void> submitAttendancePhotoFromRequest({
    required String attendanceId,
    required bool isCheckIn,
    required String photoBase64,
    required String expectedStartTime,
    required AttendanceCaptureMeta captureMeta,
  }) async {
    final thread = activeThread.value;
    if (thread == null) throw Exception('Không tìm thấy phòng chat');

    isUploading.value = true;
    try {
      await _service.submitAttendancePhotoFromRequest(
        groupId: thread.groupId,
        jobId: thread.jobId,
        attendanceId: attendanceId,
        isCheckIn: isCheckIn,
        photoBase64: photoBase64,
        expectedStartTime: expectedStartTime,
        captureMeta: captureMeta,
      );
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> checkOut() async {
    final thread = activeThread.value;
    if (thread != null && !thread.isGroupChat) {
      throw Exception('Điểm danh chỉ dùng trong nhóm chat ca làm');
    }
    final candidateId = _attendanceCandidateId;
    if (thread == null || candidateId == null) {
      throw Exception(
        isEmployer
            ? 'Chỉ ứng viên mới điểm danh cuối ca'
            : 'Bạn không thể điểm danh trong hội thoại này',
      );
    }

    isSending.value = true;
    try {
      await _service.checkOutShift(
        groupId: thread.groupId,
        jobId: thread.jobId,
        employerId: thread.employerId,
        candidateId: candidateId,
      );
    } finally {
      isSending.value = false;
    }
  }

  Future<void> sendImage(File file) async {
    final thread = activeThread.value;
    if (thread == null) return;

    isUploading.value = true;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 700 * 1024) {
        throw Exception('Ảnh quá lớn (tối đa 700KB). Chọn ảnh nhỏ hơn.');
      }
      final ext = file.path.split('.').last.toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      await _service.sendAttachmentMessage(
        groupId: thread.groupId,
        type: 'image',
        content: '[Hình ảnh]',
        attachmentUrl: 'data:$mime;base64,${base64Encode(bytes)}',
      );
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> sendAudio(File file, Duration duration) async {
    final thread = activeThread.value;
    if (thread == null) return;

    isUploading.value = true;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 700 * 1024) {
        throw Exception('Ghi âm quá dài. Tối đa khoảng 30 giây.');
      }
      final totalSec = duration.inSeconds;
      final label =
          '${(totalSec ~/ 60).toString().padLeft(2, '0')}:${(totalSec % 60).toString().padLeft(2, '0')}';
      await _service.sendAttachmentMessage(
        groupId: thread.groupId,
        type: 'audio',
        content: label,
        attachmentUrl: 'data:audio/mp4;base64,${base64Encode(bytes)}',
      );
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> sendFile(File file, String fileName) async {
    final thread = activeThread.value;
    if (thread == null) return;

    isUploading.value = true;
    try {
      final bytes = await file.readAsBytes();
      const limitBytes = 500 * 1024;
      if (bytes.lengthInBytes > limitBytes) {
        throw Exception(
          'File quá lớn (${(bytes.lengthInBytes / 1024).round()}KB). Tối đa 500KB.',
        );
      }
      final ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'bin';
      final mime = _mimeFromExt(ext);
      await _service.sendAttachmentMessage(
        groupId: thread.groupId,
        type: 'file',
        content: fileName,
        attachmentUrl: 'data:$mime;base64,${base64Encode(bytes)}',
        metadata: {'size': bytes.lengthInBytes, 'ext': ext},
      );
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> sendLocation({
    required double lat,
    required double lng,
    double accuracy = 0,
  }) async {
    final thread = activeThread.value;
    if (thread == null) return;

    isUploading.value = true;
    try {
      await _service.sendAttachmentMessage(
        groupId: thread.groupId,
        type: 'location',
        content: '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
        metadata: {'lat': lat, 'lng': lng, 'accuracy': accuracy},
      );
    } finally {
      isUploading.value = false;
    }
  }

  String _mimeFromExt(String ext) => switch (ext) {
        'pdf' => 'application/pdf',
        'doc' || 'docx' => 'application/msword',
        'xls' || 'xlsx' => 'application/vnd.ms-excel',
        'ppt' || 'pptx' => 'application/vnd.ms-powerpoint',
        'txt' => 'text/plain',
        'zip' => 'application/zip',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/octet-stream',
      };

  Future<void> sendSchedule({
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    final thread = activeThread.value;
    if (thread != null && !thread.isGroupChat) {
      throw Exception('Gửi lịch ca chỉ dùng trong nhóm chat ca làm');
    }
    if (thread == null) return;

    final candidateId = isEmployer
        ? (thread.candidateId ?? thread.memberIds.firstWhere(
            (id) => id != thread.employerId,
            orElse: () => '',
          ))
        : _attendanceCandidateId;
    if (candidateId == null || candidateId.isEmpty) {
      throw Exception('Không xác định được ứng viên cho lịch ca');
    }

    isSending.value = true;
    try {
      await _service.createSchedule(
        groupId: thread.groupId,
        jobId: thread.jobId,
        employerId: thread.employerId,
        candidateId: candidateId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        jobTitle: thread.jobTitle,
        employerName: thread.peerName,
      );
    } finally {
      isSending.value = false;
    }
  }
}

class _MessageNotifHint {
  final String groupId;
  final String title;
  final String preview;
  final String jobTitle;
  final bool isGroupChat;
  final DateTime at;

  const _MessageNotifHint({
    required this.groupId,
    required this.title,
    required this.preview,
    required this.jobTitle,
    required this.isGroupChat,
    required this.at,
  });
}
