import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/disbursement_notice_model.dart';
import 'notification_service.dart';

class JobWorkflowService {
  final _db = FirebaseFirestore.instance;
  final _notif = NotificationService();

  CollectionReference<Map<String, dynamic>> get _notices =>
      _db.collection('disbursementNotices');

  /// Chưa hoàn tất / chờ admin → không xóa bài đăng.
  Future<bool> hasBlockingDisbursementNotice(String jobId) async {
    final snap = await _notices.where('jobId', isEqualTo: jobId).limit(10).get();
    for (final doc in snap.docs) {
      final s = doc.data()['status'] as String? ?? '';
      if (s == 'pending_admin' ||
          s == 'approved' ||
          s == 'pending_ack') {
        return true;
      }
    }
    return false;
  }

  /// Đã giải ngân xong — không nhắc NTD nữa.
  Future<bool> hasCompletedDisbursement(String jobId) async {
    final snap = await _notices
        .where('jobId', isEqualTo: jobId)
        .where('status', isEqualTo: 'completed')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<DisbursementNoticeModel?> getActiveRequestForJob(String jobId) async {
    final snap = await _notices
        .where('jobId', isEqualTo: jobId)
        .where('status', whereIn: ['pending_admin', 'approved'])
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return DisbursementNoticeModel.fromMap(d.data(), d.id);
  }

  Stream<DisbursementNoticeModel?> streamActiveRequestForJob(String jobId) {
    return _notices
        .where('jobId', isEqualTo: jobId)
        .where('status', whereIn: ['pending_admin', 'approved'])
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first;
      return DisbursementNoticeModel.fromMap(d.data(), d.id);
    });
  }

  /// NTD gửi yêu cầu giải ngân — chờ Admin duyệt.
  Future<String> requestDisbursement({
    required String jobId,
    required String groupId,
    required String employerId,
    required String workDate,
    required double amount,
    required String jobTitle,
  }) async {
    final existing = await getActiveRequestForJob(jobId);
    if (existing != null) {
      throw Exception('Đã có yêu cầu giải ngân đang chờ xử lý.');
    }

    final ref = _notices.doc();
    await ref.set({
      'jobId': jobId,
      'groupId': groupId,
      'employerId': employerId,
      'workDate': workDate,
      'amount': amount,
      'jobTitle': jobTitle,
      'status': 'pending_admin',
      'employerAck': false,
      'adminAck': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _notifyAdmins(
      type: 'disbursement_request',
      title: 'Yêu cầu giải ngân',
      body:
          'NTD yêu cầu giải ngân ${amount.toStringAsFixed(0)}₫ — "$jobTitle". Vui lòng duyệt trong Admin.',
      data: {'noticeId': ref.id, 'jobId': jobId, 'groupId': groupId},
    );

    await _notif.create(
      recipientId: employerId,
      type: 'disbursement_pending',
      title: 'Đang chờ Admin duyệt',
      body:
          'Yêu cầu giải ngân $amount₫ đã gửi. Bạn chỉ giải ngân sau khi Admin cho phép.',
      data: {'noticeId': ref.id, 'jobId': jobId},
    );

    return ref.id;
  }

  /// Admin duyệt — NTD mới được giải ngân.
  Future<void> approveDisbursementRequest(String noticeId) async {
    final snap = await _notices.doc(noticeId).get();
    if (!snap.exists) return;
    final data = snap.data()!;
    if ((data['status'] as String?) != 'pending_admin') {
      throw Exception('Yêu cầu không còn ở trạng thái chờ duyệt.');
    }

    await _notices.doc(noticeId).update({
      'status': 'approved',
      'adminAck': true,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    final employerId = data['employerId'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final jobTitle = data['jobTitle'] as String? ?? '';

    await _notif.create(
      recipientId: employerId,
      type: 'disbursement_approved',
      title: 'Admin đã cho phép giải ngân',
      body:
          'Bạn có thể giải ngân $amount₫ cho "$jobTitle". Mở Điểm danh → Giải ngân.',
      data: {
        'noticeId': noticeId,
        'jobId': data['jobId'],
        'groupId': data['groupId'],
      },
    );
  }

  /// NTD xác nhận đã giải ngân (sau khi Admin duyệt).
  Future<void> executeDisbursement(String noticeId) async {
    final snap = await _notices.doc(noticeId).get();
    if (!snap.exists) throw Exception('Không tìm thấy yêu cầu');
    final data = snap.data()!;
    if (data['status'] != 'approved') {
      throw Exception('Admin chưa cho phép giải ngân.');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != data['employerId']) {
      throw Exception('Chỉ nhà tuyển dụng mới được xác nhận giải ngân.');
    }

    final groupId = data['groupId'] as String? ?? '';
    final jobId = data['jobId'] as String? ?? '';

    await _notices.doc(noticeId).update({
      'status': 'completed',
      'employerAck': true,
      'completedAt': FieldValue.serverTimestamp(),
    });

    if (groupId.isNotEmpty) {
      await _groups.doc(groupId).update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'closedReason': 'disbursement_completed',
      });
    }
    if (jobId.isNotEmpty) {
      await _db.collection('jobPosts').doc(jobId).update({
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await _notifyAdmins(
      type: 'disbursement_completed',
      title: 'Đã giải ngân',
      body: 'NTD đã xác nhận giải ngân cho "${data['jobTitle']}".',
      data: {'noticeId': noticeId, 'jobId': data['jobId']},
    );
  }

  /// Admin từ chối yêu cầu.
  Future<void> rejectDisbursementRequest(String noticeId, {String? reason}) async {
    final snap = await _notices.doc(noticeId).get();
    if (!snap.exists) return;
    final data = snap.data()!;

    await _notices.doc(noticeId).update({
      'status': 'rejected',
      'rejectReason': reason ?? '',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    await _notif.create(
      recipientId: data['employerId'] as String? ?? '',
      type: 'disbursement_rejected',
      title: 'Admin từ chối giải ngân',
      body: reason?.isNotEmpty == true
          ? reason!
          : 'Liên hệ Admin hoặc gửi lại yêu cầu.',
      data: {'noticeId': noticeId},
    );
  }

  /// Admin đóng nhóm + job (thay cho giải ngân).
  Future<void> adminCloseGroup({
    required String noticeId,
    required String groupId,
    required String jobId,
  }) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';

    await _groups.doc(groupId).update({
      'status': 'closed',
      'closedBy': adminId,
      'closedAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('jobPosts').doc(jobId).update({
      'status': 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (noticeId.isNotEmpty) {
      await _notices.doc(noticeId).update({
        'status': 'group_closed',
        'adminAck': true,
        'closedAt': FieldValue.serverTimestamp(),
      });
      final snap = await _notices.doc(noticeId).get();
      final employerId = snap.data()?['employerId'] as String? ?? '';
      if (employerId.isNotEmpty) {
        await _notif.create(
          recipientId: employerId,
          type: 'group_closed_by_admin',
          title: 'Admin đã đóng nhóm',
          body: 'Nhóm công việc đã được Admin đóng. Không cần giải ngân qua app.',
          data: {'groupId': groupId, 'jobId': jobId},
        );
      }
    }
  }

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groupChats');

  Future<List<DisbursementNoticeModel>> listPendingForAdmin() async {
    final snap = await _notices
        .where('status', isEqualTo: 'pending_admin')
        .limit(50)
        .get();
    final list = snap.docs
        .map((d) => DisbursementNoticeModel.fromMap(d.data(), d.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _notifyAdmins({
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final admins = await _db
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .limit(15)
        .get();
    for (final admin in admins.docs) {
      await _notif.create(
        recipientId: admin.id,
        type: type,
        title: title,
        body: body,
        data: data,
      );
    }
  }

  Future<void> submitEmployerRating({
    required String jobId,
    required String candidateId,
    required double rating,
    String? comment,
  }) async {
    final reviewerId = FirebaseAuth.instance.currentUser?.uid;
    if (reviewerId == null) return;

    final dup = await _db
        .collection('reviews')
        .where('reviewerId', isEqualTo: reviewerId)
        .where('revieweeId', isEqualTo: candidateId)
        .where('jobId', isEqualTo: jobId)
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty) return;

    await _db.collection('reviews').add({
      'jobId': jobId,
      'reviewerId': reviewerId,
      'revieweeId': candidateId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
