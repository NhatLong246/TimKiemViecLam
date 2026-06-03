import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../data/models/app_notification_model.dart';
import '../data/models/messaging_models.dart';
import '../data/models/notification_model.dart';
import '../data/services/notification_service.dart';
import '../utils/messaging_bootstrap.dart';
import 'messaging_controller.dart';

class EmployerNotificationController extends GetxController {
  final _svc = NotificationService();
  final _db = FirebaseFirestore.instance;

  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;

  /// Số hiển thị trên chuông — reactive, gồm thông báo + tin nhắn chưa đọc.
  final RxInt unreadBadgeCount = 0.obs;
  final RxBool isLoading = false.obs;

  StreamSubscription<List<NotificationModel>>? _notifSub;
  StreamSubscription<List<AppNotificationItem>>? _inboxSub;
  StreamSubscription<QuerySnapshot>? _appSub; // applications
  StreamSubscription<QuerySnapshot>? _postSub; // job posts

  List<NotificationModel> _legacyList = [];
  List<NotificationModel> _inboxList = [];
  List<NotificationModel> _chatUnreadList = [];
  Worker? _chatUnreadWorker;
  Worker? _chatTotalWorker;
  bool _streamsStarted = false;

  // Theo dõi trạng thái bài đăng trước đó (để phát hiện thay đổi)
  final Map<String, String> _prevPostStatuses = {};
  bool _postInitialLoad = true;

  // Theo dõi ID đơn ứng tuyển đã biết
  final Set<String> _knownAppIds = {};
  bool _appInitialLoad = true;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  int get unreadCount => unreadBadgeCount.value;

  @override
  void onInit() {
    super.onInit();
    _startStreams();
    _bindChatUnread();
  }

  @override
  void onClose() {
    _notifSub?.cancel();
    _inboxSub?.cancel();
    _appSub?.cancel();
    _postSub?.cancel();
    _chatUnreadWorker?.dispose();
    _chatTotalWorker?.dispose();
    super.onClose();
  }

  bool _refreshScheduled = false;
  bool _mergeScheduled = false;

  /// Đồng bộ chuông + danh sách (gọi khi mở Home / Thông báo hoặc sau khi inbox chat load).
  void refreshNow() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    Future.microtask(() {
      _refreshScheduled = false;
      if (isClosed) return;
      _syncChatUnreadFromInbox();
      _refreshBadgeCount();
    });
  }

  void _startStreams() {
    final uid = _uid;
    if (uid == null) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!isClosed) _startStreams();
      });
      return;
    }
    if (_streamsStarted) return;
    _streamsStarted = true;

    // 1. Gộp thông báo legacy (`notifications`) + hộp thư (`users/.../notifications`)
    _notifSub?.cancel();
    _notifSub = _svc.streamByRecipient(uid).listen((list) {
      _legacyList = list;
      _mergeNotifications();
    }, onError: (_) => _fetchLegacyFallback(uid));

    _inboxSub?.cancel();
    _inboxSub = _svc.streamNotifications(userId: uid).listen((items) {
      _inboxList = items.map((i) => _fromAppItem(i, uid)).toList();
      _mergeNotifications();
    }, onError: (_) => _fetchInboxFallback(uid));

    // 2. Theo dõi bài đăng — phát hiện approved/rejected
    _postSub = _db
        .collection('jobPosts')
        .where('employerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) async {
          if (_postInitialLoad) {
            // Ghi nhớ trạng thái ban đầu, không tạo thông báo
            for (final doc in snap.docs) {
              final status = doc.data()['status'] as String? ?? '';
              _prevPostStatuses[doc.id] = status;
            }
            _postInitialLoad = false;
            return;
          }

          for (final change in snap.docChanges) {
            if (change.type == DocumentChangeType.modified) {
              final data = change.doc.data() as Map<String, dynamic>;
              final newStatus = data['status'] as String? ?? '';
              final oldStatus = _prevPostStatuses[change.doc.id] ?? '';
              final title = data['title'] as String? ?? 'Bài đăng';

              if (oldStatus != newStatus) {
                if (newStatus == 'approved') {
                  await _svc.notifyEmployer(
                    employerId: uid,
                    type: 'post_approved',
                    title: '✅ Bài đăng được duyệt',
                    body:
                        '"$title" đã được admin phê duyệt và hiển thị trên ứng dụng.',
                    category: NotificationCategory.system,
                    data: {'postId': change.doc.id, 'title': title},
                  );
                } else if (newStatus == 'rejected') {
                  await _svc.notifyEmployer(
                    employerId: uid,
                    type: 'post_rejected',
                    title: '❌ Bài đăng bị từ chối',
                    body:
                        '"$title" đã bị từ chối. Vui lòng chỉnh sửa và gửi lại.',
                    category: NotificationCategory.system,
                    data: {'postId': change.doc.id, 'title': title},
                  );
                }
              }
              _prevPostStatuses[change.doc.id] = newStatus;
            } else if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              _prevPostStatuses[change.doc.id] =
                  data['status'] as String? ?? '';
            }
          }
        });

    // 3. Theo dõi đơn ứng tuyển — phát hiện đơn mới
    _appSub = _db
        .collection('applications')
        .where('employerId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('appliedAt', descending: true)
        .limit(30)
        .snapshots()
        .listen((snap) async {
          if (_appInitialLoad) {
            for (final doc in snap.docs) {
              _knownAppIds.add(doc.id);
            }
            _appInitialLoad = false;
            return;
          }

          for (final change in snap.docChanges) {
            if (change.type == DocumentChangeType.added) {
              _knownAppIds.add(change.doc.id);
            }
          }
        });
  }

  void _mergeNotifications() {
    if (_mergeScheduled) return;
    _mergeScheduled = true;
    Future.microtask(() {
      _mergeScheduled = false;
      if (isClosed) return;
      _applyMergedNotifications();
    });
  }

  bool _isMutedMessageNotif(NotificationModel n) {
    if (n.type != 'message') return false;
    final gid = (n.data['groupId'] ?? '').toString();
    if (gid.isEmpty) return false;
    if (!Get.isRegistered<MessagingController>()) return false;
    return Get.find<MessagingController>().isGroupNotificationsMuted(gid);
  }

  void _applyMergedNotifications() {
    final byKey = <String, NotificationModel>{};
    for (final n in _legacyList) {
      if (_isMutedMessageNotif(n)) continue;
      byKey[_dedupeKey(n)] = n;
    }
    for (final n in _inboxList) {
      if (_isMutedMessageNotif(n)) continue;
      final key = _dedupeKey(n);
      final existing = byKey[key];
      if (existing == null || n.createdAt.isAfter(existing.createdAt)) {
        byKey[key] = n;
      }
    }
    // Tin chưa đọc trên hội thoại (chuông đỏ) — hiển thị khi chưa có doc Firestore tương ứng.
    for (final n in _chatUnreadList) {
      if (_isMutedMessageNotif(n)) continue;
      byKey.putIfAbsent(_dedupeKey(n), () => n);
    }
    final merged = byKey.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifications.assignAll(merged.take(80).toList());
    _refreshBadgeCount();
  }

  void _refreshBadgeCount() {
    final fromList = notifications.where((n) => !n.isRead).length;
    final chatUnread = Get.isRegistered<MessagingController>()
        ? Get.find<MessagingController>().unreadTotal.value
        : 0;
    unreadBadgeCount.value = fromList > chatUnread ? fromList : chatUnread;
  }

  String _dedupeKey(NotificationModel n) {
    if (n.type == 'message') {
      final gid = (n.data['groupId'] ?? '').toString();
      if (gid.isNotEmpty) return 'msg_$gid';
    }
    if (n.type == 'application' || n.type == 'application_withdrawn') {
      final appId = (n.data['appId'] ?? '').toString();
      if (appId.isNotEmpty) return '${n.type}_app_$appId';
      final jobId = (n.data['jobId'] ?? '').toString();
      final candidateId = (n.data['candidateId'] ?? '').toString();
      if (jobId.isNotEmpty && candidateId.isNotEmpty) {
        return '${n.type}_job_${jobId}_candidate_$candidateId';
      }
    }
    if (n.type == 'post_approved' || n.type == 'post_rejected') {
      final postId = (n.data['postId'] ?? n.data['jobId'] ?? '').toString();
      if (postId.isNotEmpty) return '${n.type}_post_$postId';
    }
    if (n.type == 'attendance_result') {
      final gid = (n.data['groupId'] ?? '').toString();
      if (gid.isNotEmpty) return 'att_$gid';
    }
    if (n.type == 'application_deadline_underfilled') {
      final jobId = (n.data['jobId'] ?? '').toString();
      if (jobId.isNotEmpty) return 'underfilled_job_$jobId';
    }
    if (n.type == 'job_work_period_ended' ||
        n.type == 'disbursement_ready' ||
        n.type == 'disbursement_reminder' ||
        n.type == 'disbursement_pending') {
      final jobId = (n.data['jobId'] ?? '').toString();
      if (jobId.isNotEmpty) return 'disburse_job_$jobId';
    }
    return '${n.type}_${n.notifId}';
  }

  NotificationModel _fromAppItem(AppNotificationItem item, String uid) {
    var type = item.data['type']?.toString() ?? '';
    if (type.isEmpty) {
      type = switch (item.category) {
        NotificationCategory.message => 'message',
        NotificationCategory.job when item.isAttendanceResult =>
          'attendance_result',
        NotificationCategory.job when item.data['type'] == 'application' =>
          'application',
        NotificationCategory.job => 'application',
        NotificationCategory.profile when item.data['type'] == 'review' =>
          'review',
        _ => 'system',
      };
    }
    return NotificationModel(
      notifId: 'inbox:${item.id}',
      recipientId: uid,
      type: type,
      title: item.title,
      body: item.body,
      data: item.data,
      isRead: item.isRead,
      createdAt: item.createdAt,
    );
  }

  void _bindChatUnread() {
    Future.microtask(() {
      if (isClosed) return;
      final mc = MessagingBootstrap.ensureController();
      mc.ensureInboxListening();
      _chatUnreadWorker?.dispose();
      _chatTotalWorker?.dispose();
      _chatUnreadWorker = ever(mc.conversations, (_) => refreshNow());
      _chatTotalWorker = ever(mc.unreadTotal, (_) => refreshNow());
      refreshNow();
      for (final ms in const [300, 800, 1500, 3000]) {
        Future.delayed(Duration(milliseconds: ms), () {
          if (!isClosed) refreshNow();
        });
      }
    });
  }

  void _syncChatUnreadFromInbox() {
    final uid = _uid;
    if (uid == null) return;
    if (!Get.isRegistered<MessagingController>()) {
      _chatUnreadList = [];
      _mergeNotifications();
      return;
    }
    final threads = Get.find<MessagingController>().conversations.where(
      (t) => t.unreadCount > 0 && !t.notificationsMuted,
    );
    _chatUnreadList = threads
        .map((t) => _fromUnreadThread(t, uid))
        .toList(growable: false);
    _mergeNotifications();
  }

  NotificationModel _fromUnreadThread(ConversationThread t, String uid) {
    final preview = (t.lastMessageText ?? '').trim();
    final body = t.unreadCount > 1
        ? 'Bạn có ${t.unreadCount} tin nhắn chưa đọc'
        : (preview.isNotEmpty ? preview : 'Có tin nhắn mới');
    final title = t.isGroupChat
        ? 'Tin nhắn nhóm · ${t.jobTitle}'
        : 'Tin nhắn từ ${t.peerName}';
    return NotificationModel(
      notifId: 'chat:${t.groupId}',
      recipientId: uid,
      type: 'message',
      title: title,
      body: body,
      data: {
        'groupId': t.groupId,
        'groupName': t.jobTitle,
        'unreadCount': t.unreadCount,
      },
      isRead: false,
      createdAt: t.lastMessageAt ?? DateTime.now(),
    );
  }

  Future<void> _fetchInboxFallback(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .limit(80)
          .get();
      _inboxList =
          snap.docs
              .map(
                (d) => _fromAppItem(
                  AppNotificationItem.fromMap(d.id, d.data()),
                  uid,
                ),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _mergeNotifications();
    } catch (_) {}
  }

  Future<void> _fetchLegacyFallback(String uid) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('recipientId', isEqualTo: uid)
          .limit(80)
          .get();
      _legacyList =
          snap.docs
              .map((d) => NotificationModel.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _mergeNotifications();
    } catch (_) {}
  }

  bool _isInboxId(String notifId) => notifId.startsWith('inbox:');

  bool _isChatId(String notifId) => notifId.startsWith('chat:');

  String _inboxDocId(String notifId) => notifId.substring('inbox:'.length);

  String _chatGroupId(String notifId) => notifId.substring('chat:'.length);

  // ── Public actions ──────────────────────────────────────────────────────────
  Future<void> markRead(String notifId) async {
    if (_isChatId(notifId)) {
      final gid = _chatGroupId(notifId);
      if (Get.isRegistered<MessagingController>()) {
        await Get.find<MessagingController>().markConversationRead(gid);
      }
      _syncChatUnreadFromInbox();
      return;
    }
    if (_isInboxId(notifId)) {
      await _svc.markRead(_inboxDocId(notifId));
      return;
    }
    await _svc.markLegacyRead(notifId);
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    await _svc.markAllReadForRecipient(uid);
    await _svc.markAllRead();
    if (Get.isRegistered<MessagingController>()) {
      await Get.find<MessagingController>().markAllUnreadConversationsRead();
    }
    _syncChatUnreadFromInbox();
  }

  Future<void> deleteNotif(String notifId) async {
    if (_isChatId(notifId)) {
      await markRead(notifId);
      return;
    }
    if (_isInboxId(notifId)) {
      await _svc.deleteNotification(_inboxDocId(notifId));
      return;
    }
    await _svc.deleteLegacy(notifId);
  }

  Future<void> clearRead() async {
    final uid = _uid;
    if (uid == null) return;
    await _svc.clearLegacyRead(uid);
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: true)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> deleteAll() async {
    final uid = _uid;
    if (uid == null) return;
    await _svc.deleteAllLegacyForRecipient(uid);
    await _svc.deleteAll();
  }

  // ── Tạo thông báo tin nhắn thủ công (gọi khi có unread messages) ──────────
  Future<void> createMessageNotif({
    required String groupId,
    required String groupName,
    required String senderName,
    required String preview,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _svc.notifyEmployer(
      employerId: uid,
      type: 'message',
      title: '💬 $groupName',
      body: '$senderName: $preview',
      category: NotificationCategory.message,
      data: {'groupId': groupId, 'groupName': groupName},
    );
  }
}
