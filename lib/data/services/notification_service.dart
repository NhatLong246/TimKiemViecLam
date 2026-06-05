import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_notification_model.dart';
import '../models/notification_model.dart';
import '../../utils/preferences_helper.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference get _legacyCol => _db.collection('notifications');

  CollectionReference<Map<String, dynamic>>? _userNotificationsCol(String uid) {
    return _db.collection('users').doc(uid).collection('notifications');
  }

  // ── Employer legacy (top-level `notifications` collection) ─────────────────

  Future<void> create({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
    bool suppressPush = false,
  }) async {
    await _legacyCol.add({
      'recipientId': recipientId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'isRead': false,
      if (suppressPush) 'suppressPush': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<NotificationModel>> streamByRecipient(String recipientId) {
    // Không orderBy trên Firestore — tránh lỗi thiếu composite index (stream rỗng im lặng).
    return _legacyCol
        .where('recipientId', isEqualTo: recipientId)
        .limit(80)
        .snapshots()
        .map((snap) {
          final list =
              snap.docs
                  .map(
                    (d) => NotificationModel.fromMap(
                      d.data() as Map<String, dynamic>,
                      d.id,
                    ),
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list.take(50).toList();
        });
  }

  Future<void> markLegacyRead(String notifId) async {
    await _legacyCol.doc(notifId).update({'isRead': true});
  }

  Future<void> markAllReadForRecipient(String recipientId) async {
    final snap = await _legacyCol
        .where('recipientId', isEqualTo: recipientId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteLegacy(String notifId) async {
    await _legacyCol.doc(notifId).delete();
  }

  Future<void> deleteAllLegacyForRecipient(String recipientId) async {
    final snap = await _legacyCol
        .where('recipientId', isEqualTo: recipientId)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> clearLegacyRead(String recipientId) async {
    final snap = await _legacyCol
        .where('recipientId', isEqualTo: recipientId)
        .where('isRead', isEqualTo: true)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── User inbox (users/{uid}/notifications subcollection) ───────────────────

  Stream<List<AppNotificationItem>> streamNotifications({String? userId}) {
    final uid = userId ?? _uid;
    if (uid == null) return Stream.value([]);

    return _userNotificationsCol(uid)!
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs
              .map((d) => AppNotificationItem.fromMap(d.id, d.data()))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Cùng logic với màn Thông báo: đếm `isRead == false` (không lọc watermark).
  Stream<int> streamUnreadCount({String? userId}) {
    final uid = userId ?? _uid;
    if (uid == null) return Stream.value(0);

    return streamNotifications(
      userId: uid,
    ).map((list) => list.where((n) => !n.isRead).length);
  }

  Future<void> markRead(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;
    await _userNotificationsCol(
      uid,
    )!.doc(notificationId).update({'isRead': true});
  }

  bool _notificationIsUnread(Map<String, dynamic> data) =>
      data['isRead'] != true;

  String _notificationGroupId(Map<String, dynamic> data) {
    final meta = data['data'];
    if (meta is Map) {
      return (meta['groupId'] ?? '').toString();
    }
    return '';
  }

  /// NTD: đánh dấu đã đọc thông báo tin nhắn (collection `notifications`).
  Future<void> markLegacyMessageNotificationsReadForGroup(
    String groupId, {
    required String recipientId,
  }) async {
    if (groupId.isEmpty || recipientId.isEmpty) return;

    final snap = await _legacyCol
        .where('recipientId', isEqualTo: recipientId)
        .where('type', isEqualTo: 'message')
        .where('isRead', isEqualTo: false)
        .limit(50)
        .get();

    final batch = _db.batch();
    var n = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final meta = data['data'];
      final gid = meta is Map
          ? (meta['groupId'] ?? '').toString()
          : (data['groupId'] ?? '').toString();
      if (gid != groupId) continue;
      batch.update(doc.reference, {'isRead': true});
      n++;
    }
    if (n > 0) await batch.commit();
  }

  /// Đánh dấu đã đọc thông báo tin nhắn của một phòng chat.
  Future<void> markMessageNotificationsReadForGroup(
    String groupId, {
    String? userId,
  }) async {
    final uid = userId ?? _uid;
    if (uid == null || groupId.isEmpty) return;

    final snap = await _userNotificationsCol(uid)!.limit(80).get();
    final batch = _db.batch();
    var n = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (!_notificationIsUnread(data)) continue;
      if (data['category']?.toString() != 'message') continue;
      if (_notificationGroupId(data) != groupId) continue;
      batch.update(doc.reference, {'isRead': true});
      n++;
    }
    if (n > 0) await batch.commit();
    await ChatReadPreferences.markRead(uid, groupId, DateTime.now());
  }

  /// Đánh dấu đã đọc mọi thông báo loại tin nhắn (khi mở từ bong bóng nhiều hội thoại).
  Future<void> markAllMessageNotificationsRead({String? userId}) async {
    final uid = userId ?? _uid;
    if (uid == null) return;

    final snap = await _userNotificationsCol(uid)!.limit(80).get();
    final batch = _db.batch();
    var n = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (!_notificationIsUnread(data)) continue;
      if (data['category']?.toString() != 'message') continue;
      batch.update(doc.reference, {'isRead': true});
      n++;
    }
    if (n > 0) await batch.commit();
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    final snap = await _userNotificationsCol(
      uid,
    )!.where('isRead', isEqualTo: false).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;
    await _userNotificationsCol(uid)!.doc(notificationId).delete();
  }

  Future<void> deleteAll() async {
    final uid = _uid;
    if (uid == null) return;
    final snap = await _userNotificationsCol(uid)!.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<Map<String, bool>> loadPrefs() async {
    final uid = _uid;
    if (uid == null) return _defaultPrefs;

    final doc = await _db.collection('users').doc(uid).get();
    final raw = doc.data()?['notificationPrefs'];
    if (raw is! Map) return _defaultPrefs;

    return {
      'job': raw['job'] != false,
      'system': raw['system'] != false,
      'promo': raw['promo'] == true,
      'profile': raw['profile'] != false,
      'message': raw['message'] != false,
    };
  }

  Future<void> savePrefs(Map<String, bool> prefs) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'notificationPrefs': prefs,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static const _defaultPrefs = {
    'job': true,
    'system': true,
    'promo': false,
    'profile': true,
    'message': true,
  };

  /// Tránh spam thông báo điểm danh (nhiều nhóm trùng job / polling).
  Future<bool> hasRecentAttendanceRequest({
    required String userId,
    required String jobId,
    required String phase,
    Duration within = const Duration(minutes: 30),
  }) async {
    if (userId.isEmpty || jobId.isEmpty) return false;
    final col = _userNotificationsCol(userId);
    if (col == null) return false;

    final since = DateTime.now().subtract(within);
    final snap = await col.orderBy('createdAt', descending: true).limit(60).get();
    for (final doc in snap.docs) {
      final item = AppNotificationItem.fromMap(doc.id, doc.data());
      if (item.createdAt.isBefore(since)) continue;
      if (item.data['type']?.toString() != 'attendance_request') continue;
      if (item.data['jobId']?.toString() != jobId) continue;
      if (item.data['phase']?.toString() != phase) continue;
      return true;
    }
    return false;
  }

  Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.system,
    Map<String, dynamic> data = const {},
  }) async {
    final prefs = await _loadPrefsForUser(userId);
    if (!_isCategoryEnabled(prefs, category)) return;

    await _userNotificationsCol(userId)!.add({
      'title': title,
      'body': body,
      'category': category.name,
      'isRead': false,
      if (data.isNotEmpty) 'data': data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mọi sự kiện từ ứng viên/user → NTD: ghi cả `notifications` lẫn hộp thư user.
  Future<void> notifyEmployer({
    required String employerId,
    required String type,
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.job,
    Map<String, dynamic> data = const {},
  }) async {
    if (employerId.isEmpty) return;

    await create(
      recipientId: employerId,
      type: type,
      title: title,
      body: body,
      data: data,
      suppressPush: true,
    );

    await sendToUser(
      userId: employerId,
      title: title,
      body: body,
      category: category,
      data: data,
    );
  }

  Future<void> notifyNewChatMessage({
    required String recipientId,
    required String groupId,
    required String title,
    required String body,
    required int unreadCount,
    required bool isGroupChat,
    required String senderName,
    required String preview,
  }) async {
    final data = {
      'groupId': groupId,
      'type': 'message',
      'unreadCount': unreadCount,
      'isGroupChat': isGroupChat,
      'senderName': senderName,
      'preview': preview,
    };

    final role = await _roleForUser(recipientId);

    if (role == 'employer') {
      await notifyEmployer(
        employerId: recipientId,
        type: 'message',
        title: title,
        body: body,
        category: NotificationCategory.message,
        data: data,
      );
      return;
    }

    await sendToUser(
      userId: recipientId,
      title: title,
      body: body,
      category: NotificationCategory.message,
      data: data,
    );
  }

  Future<void> notifyIncomingCall({
    required String recipientId,
    required String groupId,
    required String callerName,
    required bool isVideo,
    required String roomUrl,
  }) async {
    final data = {
      'groupId': groupId,
      'type': 'call',
      'isVideo': isVideo,
      'roomUrl': roomUrl,
    };

    final role = await _roleForUser(recipientId);

    if (role == 'employer') {
      await notifyEmployer(
        employerId: recipientId,
        type: 'call',
        title: callerName,
        body: isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại',
        category: NotificationCategory.message,
        data: data,
      );
      return;
    }

    await sendToUser(
      userId: recipientId,
      title: callerName,
      body: isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại',
      category: NotificationCategory.message,
      data: data,
    );
  }

  Future<String> _roleForUser(String userId) async {
    if (userId.isEmpty) return 'candidate';
    final doc = await _db.collection('users').doc(userId).get();
    return (doc.data()?['role'] ?? 'candidate').toString();
  }

  Future<Map<String, bool>> _loadPrefsForUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final raw = doc.data()?['notificationPrefs'];
    if (raw is! Map) return _defaultPrefs;
    return {
      'job': raw['job'] != false,
      'system': raw['system'] != false,
      'promo': raw['promo'] == true,
      'profile': raw['profile'] != false,
      'message': raw['message'] != false,
    };
  }

  bool _isCategoryEnabled(
    Map<String, bool> prefs,
    NotificationCategory category,
  ) {
    switch (category) {
      case NotificationCategory.job:
        return prefs['job'] ?? true;
      case NotificationCategory.system:
        return prefs['system'] ?? true;
      case NotificationCategory.promo:
        return prefs['promo'] ?? false;
      case NotificationCategory.profile:
        return prefs['profile'] ?? true;
      case NotificationCategory.message:
        return prefs['message'] ?? true;
    }
  }

  static Future<void> notifyApplicationAccepted({
    required String candidateId,
    required String jobTitle,
    String? employerName,
    bool isFullTimeReferral = false,
  }) async {
    final svc = NotificationService();
    final name = employerName?.trim().isNotEmpty == true
        ? employerName!
        : 'Nhà tuyển dụng';
    await svc.sendToUser(
      userId: candidateId,
      title: isFullTimeReferral
          ? 'NTD đã ghi nhận đơn Full-time'
          : 'Đơn ứng tuyển được chấp nhận',
      body: isFullTimeReferral
          ? '$name đã ghi nhận bạn cho vị trí "$jobTitle". Họ sẽ liên hệ trực tiếp — ViecNow không quản lý việc Full-time.'
          : '$name đã chấp nhận bạn cho vị trí "$jobTitle". Mở tin nhắn để trao đổi.',
      category: NotificationCategory.job,
    );
  }

  static Future<void> notifyNewApplication({
    required String employerId,
    required String jobTitle,
    required String candidateName,
    String? jobId,
    String? appId,
    String? candidateId,
  }) async {
    final svc = NotificationService();
    // ── Chống trùng: nếu 30s vừa rồi đã có thông báo cùng type+job+candidate thì bỏ qua
    final isDup = await svc._hasRecentEmployerNotif(
      employerId: employerId,
      type: 'application',
      jobId: jobId ?? '',
      candidateId: candidateId ?? '',
      within: const Duration(seconds: 30),
    );
    if (isDup) return;

    await svc.notifyEmployer(
      employerId: employerId,
      type: 'application',
      title: '📋 Có ứng viên mới',
      body: '$candidateName đã ứng tuyển vào "$jobTitle".',
      category: NotificationCategory.job,
      data: {
        'type': 'application',
        if (jobId != null && jobId.isNotEmpty) 'jobId': jobId,
        if (appId != null && appId.isNotEmpty) 'appId': appId,
        if (candidateId != null && candidateId.isNotEmpty)
          'candidateId': candidateId,
      },
    );
  }


  static Future<void> notifyApplicationWithdrawn({
    required String employerId,
    required String jobTitle,
    required String candidateName,
    required bool wasAccepted,
    String? jobId,
    String? appId,
    String? candidateId,
  }) async {
    final svc = NotificationService();
    // ── Chống trùng: nếu 30s vừa rồi đã có thông báo cùng type+job+candidate thì bỏ qua
    final isDup = await svc._hasRecentEmployerNotif(
      employerId: employerId,
      type: 'application_withdrawn',
      jobId: jobId ?? '',
      candidateId: candidateId ?? '',
      within: const Duration(seconds: 30),
    );
    if (isDup) return;

    final name = candidateName.trim().isNotEmpty
        ? candidateName.trim()
        : 'Ứng viên';
    final titleText = jobTitle.trim().isNotEmpty
        ? jobTitle.trim()
        : 'Công việc';
    await svc.notifyEmployer(
      employerId: employerId,
      type: 'application_withdrawn',
      title: 'Ứng viên đã hủy ứng tuyển',
      body: wasAccepted
          ? '$name đã rút khỏi "$titleText".'
          : '$name đã hủy đơn ứng tuyển vào "$titleText".',
      category: NotificationCategory.job,
      data: {
        'type': 'application_withdrawn',
        'wasAccepted': wasAccepted,
        if (jobId != null && jobId.isNotEmpty) 'jobId': jobId,
        if (appId != null && appId.isNotEmpty) 'appId': appId,
        if (candidateId != null && candidateId.isNotEmpty)
          'candidateId': candidateId,
      },
    );
  }

  static Future<void> notifyApplicationDeadlineUnderfilled({
    required String employerId,
    required String jobTitle,
    required String jobId,
    required int filledSlots,
    required int slots,
  }) async {
    if (employerId.isEmpty || jobId.isEmpty) return;
    final svc = NotificationService();
    final titleText = jobTitle.trim().isNotEmpty
        ? jobTitle.trim()
        : 'Công việc';
    final missingSlots = (slots - filledSlots).clamp(0, slots).toInt();
    await svc.notifyEmployer(
      employerId: employerId,
      type: 'application_deadline_underfilled',
      title: 'Hết hạn ứng tuyển - chưa đủ người',
      body:
          '"$titleText" hiện có $filledSlots/$slots ứng viên, thiếu '
          '$missingSlots người. Mở Quản lý bài đăng để tiếp tục job hoặc hủy.',
      category: NotificationCategory.job,
      data: {
        'type': 'application_deadline_underfilled',
        'jobId': jobId,
        'filledSlots': filledSlots,
        'slots': slots,
        'missingSlots': missingSlots,
      },
    );
  }

  static Future<void> notifyJobCancelledToCandidate({
    required String candidateId,
    required String jobTitle,
    required String employerId,
    String? jobId,
    double compensationAmount = 0,
  }) async {
    if (candidateId.isEmpty) return;
    final svc = NotificationService();
    final titleText = jobTitle.trim().isNotEmpty
        ? jobTitle.trim()
        : 'Công việc';
    final hasCompensation = compensationAmount > 0;
    await svc.sendToUser(
      userId: candidateId,
      title: 'Công việc đã bị hủy',
      body: hasCompensation
          ? '"$titleText" đã bị hủy. Bạn được đền bù ${_formatVnd(compensationAmount)} vào ví ViecNow.'
          : '"$titleText" đã bị hủy. Đơn ứng tuyển và nhóm liên quan đã được cập nhật.',
      category: NotificationCategory.job,
      data: {
        'type': 'job_cancelled',
        'employerId': employerId,
        if (jobId != null && jobId.isNotEmpty) 'jobId': jobId,
        'compensationAmount': compensationAmount,
      },
    );
  }
  static Future<void> notifyInterestRejected({
    required String employerId,
    required String jobTitle,
    required String candidateName,
    required String candidateId,
    required String jobId,
  }) async {
    final svc = NotificationService();
    await svc.notifyEmployer(
      employerId: employerId,
      type: 'interest_rejected',
      title: '❌ Lời mời bị từ chối',
      body: '$candidateName đã từ chối lời mời thuê lại cho "$jobTitle".',
      category: NotificationCategory.job,
      data: {
        'type': 'interest_rejected',
        'jobId': jobId,
        'candidateId': candidateId,

      },
    );
  }

  static Future<void> notifyEmployerReview({
    required String employerId,
    required String candidateName,
    required String jobTitle,
    required double rating,
    String? jobId,
  }) async {
    final svc = NotificationService();
    final stars = rating.toStringAsFixed(1);
    await svc.notifyEmployer(
      employerId: employerId,
      type: 'review',
      title: '⭐ Đánh giá mới ($stars)',
      body: '$candidateName đã đánh giá bạn cho "$jobTitle".',
      category: NotificationCategory.profile,
      data: {
        'type': 'review',
        if (jobId != null && jobId.isNotEmpty) 'jobId': jobId,
        'rating': rating,
      },
    );
  }

  static String _formatVnd(double value) {
    final raw = value.round().toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write('.');
      out.write(raw[i]);
    }
    return '${out.toString()}đ';
  }

  /// Kiểm tra xem NTD đã nhận thông báo cùng type + jobId + candidateId
  /// trong khoảng thời gian [within] gần nhất chưa — dùng để chống gửi trùng.
  Future<bool> _hasRecentEmployerNotif({
    required String employerId,
    required String type,
    required String jobId,
    required String candidateId,
    Duration within = const Duration(seconds: 30),
  }) async {
    if (employerId.isEmpty) return false;
    try {
      final since = DateTime.now().subtract(within);
      // Kiểm tra trong legacy collection `notifications`
      final snap = await _legacyCol
          .where('recipientId', isEqualTo: employerId)
          .where('type', isEqualTo: type)
          .limit(20)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null || createdAt.isBefore(since)) continue;
        final meta = data['data'];
        if (meta is Map) {
          final existingJob = (meta['jobId'] ?? '').toString();
          final existingCandidate = (meta['candidateId'] ?? '').toString();
          if (existingJob == jobId && existingCandidate == candidateId) {
            return true; // Đã có thông báo trùng trong khoảng thời gian
          }
        }
      }
    } catch (_) {
      // Nếu lỗi kiểm tra thì vẫn cho phép gửi thông báo (fail-open)
    }
    return false;
  }
}
