import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../data/models/notification_model.dart';
import '../data/services/notification_service.dart';

class EmployerNotificationController extends GetxController {
  final _svc = NotificationService();
  final _db = FirebaseFirestore.instance;

  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = false.obs;

  StreamSubscription<List<NotificationModel>>? _notifSub;
  StreamSubscription<QuerySnapshot>? _appSub;    // applications
  StreamSubscription<QuerySnapshot>? _postSub;   // job posts

  // Theo dõi trạng thái bài đăng trước đó (để phát hiện thay đổi)
  final Map<String, String> _prevPostStatuses = {};
  bool _postInitialLoad = true;

  // Theo dõi ID đơn ứng tuyển đã biết
  final Set<String> _knownAppIds = {};
  bool _appInitialLoad = true;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  void onInit() {
    super.onInit();
    _startStreams();
  }

  @override
  void onClose() {
    _notifSub?.cancel();
    _appSub?.cancel();
    _postSub?.cancel();
    super.onClose();
  }

  void _startStreams() {
    final uid = _uid;
    if (uid == null) return;

    // 1. Stream thông báo từ Firestore
    _notifSub = _svc.streamByRecipient(uid).listen((list) {
      notifications.value = list;
    });

    // 2. Theo dõi bài đăng — phát hiện approved/rejected
    _postSub = _db
        .collection('jobPosts')
        .where('employerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
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
              _svc.create(
                recipientId: uid,
                type: 'post_approved',
                title: '✅ Bài đăng được duyệt',
                body: '"$title" đã được admin phê duyệt và hiển thị trên ứng dụng.',
                data: {'postId': change.doc.id, 'title': title},
              );
            } else if (newStatus == 'rejected') {
              _svc.create(
                recipientId: uid,
                type: 'post_rejected',
                title: '❌ Bài đăng bị từ chối',
                body: '"$title" đã bị từ chối. Vui lòng chỉnh sửa và gửi lại.',
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
        if (change.type == DocumentChangeType.added &&
            !_knownAppIds.contains(change.doc.id)) {
          _knownAppIds.add(change.doc.id);
          final data = change.doc.data() as Map<String, dynamic>;
          final jobId = data['jobId'] as String? ?? '';
          final candidateId = data['candidateId'] as String? ?? '';

          // Lấy tên bài đăng + tên ứng viên
          String jobTitle = 'bài đăng';
          String candidateName = 'Ứng viên';

          try {
            final jobDoc =
                await _db.collection('jobPosts').doc(jobId).get();
            if (jobDoc.exists) {
              jobTitle = jobDoc.data()?['title'] as String? ?? jobTitle;
            }

            final userDoc =
                await _db.collection('users').doc(candidateId).get();
            if (userDoc.exists) {
              final first =
                  userDoc.data()?['firstName'] as String? ?? '';
              final last = userDoc.data()?['lastName'] as String? ?? '';
              final combined = '$first $last'.trim();
              if (combined.isNotEmpty) candidateName = combined;
            }
          } catch (_) {}

          await _svc.create(
            recipientId: uid,
            type: 'application',
            title: '📋 Có ứng viên mới',
            body: '$candidateName đã ứng tuyển vào "$jobTitle".',
            data: {
              'appId': change.doc.id,
              'jobId': jobId,
              'candidateId': candidateId,
            },
          );
        }
      }
    });
  }

  // ── Public actions ──────────────────────────────────────────────────────────
  Future<void> markRead(String notifId) => _svc.markRead(notifId);

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    await _svc.markAllRead(uid);
  }

  Future<void> deleteNotif(String notifId) => _svc.delete(notifId);

  Future<void> clearRead() async {
    final uid = _uid;
    if (uid == null) return;
    await _svc.clearRead(uid);
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
    await _svc.create(
      recipientId: uid,
      type: 'message',
      title: '💬 $groupName',
      body: '$senderName: $preview',
      data: {'groupId': groupId, 'groupName': groupName},
    );
  }
}
