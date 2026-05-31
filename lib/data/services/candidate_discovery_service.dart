import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/job_criteria_model.dart';
import '../models/app_notification_model.dart';
import 'notification_service.dart';

/// Lưu thông tin ứng viên kèm tiêu chí tìm việc.
class DiscoverableCandidate {
  final UserModel user;
  final JobCriteriaModel criteria;

  const DiscoverableCandidate({required this.user, required this.criteria});
}

/// Danh sách ứng viên cho phép NTD tìm thấy hồ sơ (`allowEmployerDiscovery: true`).
class CandidateDiscoveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Lấy danh sách ứng viên đang tìm việc Full-time.
  /// Chỉ trả về user có `allowEmployerDiscovery: true`,
  /// role = candidate, isActive = true,
  /// và `jobCriteria.workTypes` chứa "Toàn thời gian".
  Future<List<DiscoverableCandidate>> fetchFullTimeCandidates({
    String? keyword,
    int limit = 50,
  }) async {
    final snap = await _db
        .collection('users')
        .where('allowEmployerDiscovery', isEqualTo: true)
        .limit(limit)
        .get();

    final results = <DiscoverableCandidate>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      data['uid'] = doc.id; // đảm bảo id luôn có

      // Chỉ lấy candidate đang hoạt động
      final role = (data['role'] ?? '').toString();
      final isActive = data['isActive'] as bool? ?? true;
      if (role != 'candidate' || !isActive) continue;

      // Phải có tiêu chí tìm việc
      final criteria = JobCriteriaModel.fromUserData(data);
      if (criteria == null) continue;

      // Chỉ lấy ứng viên tìm Full-time
      final hasFullTime = criteria.workTypes.any((t) =>
          t.toLowerCase().contains('toàn thời gian') ||
          t.toLowerCase().contains('full'));
      if (!hasFullTime) continue;

      final user = UserModel.fromMap(data);

      // Lọc theo keyword (tên, email, username)
      if (keyword != null && keyword.trim().isNotEmpty) {
        final q = keyword.trim().toLowerCase();
        final match = user.fullName.toLowerCase().contains(q) ||
            user.username.toLowerCase().contains(q) ||
            user.email.toLowerCase().contains(q) ||
            criteria.position.toLowerCase().contains(q) ||
            criteria.careers.any((c) => c.toLowerCase().contains(q));
        if (!match) continue;
      }

      results.add(DiscoverableCandidate(user: user, criteria: criteria));
    }

    return results;
  }

  /// Fetch cũ (giữ cho backward-compatible).
  Future<List<UserModel>> fetchDiscoverableCandidates({
    String? keyword,
    int limit = 50,
  }) async {
    final snap = await _db
        .collection('users')
        .where('allowEmployerDiscovery', isEqualTo: true)
        .limit(limit)
        .get();

    var candidates = snap.docs
        .map((d) {
          final data = d.data();
          data['uid'] = d.id;
          return UserModel.fromMap(data);
        })
        .where((u) => u.role == 'candidate' && u.isActive)
        .toList();

    if (keyword != null && keyword.trim().isNotEmpty) {
      final q = keyword.trim().toLowerCase();
      candidates = candidates.where((u) {
        return u.fullName.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q);
      }).toList();
    }

    return candidates;
  }

  /// Kiểm tra NTD đã gửi quan tâm cho ứng viên này với job này chưa.
  Future<bool> checkIfAlreadySent({
    required String employerId,
    required String candidateId,
    required String jobId,
  }) async {
    final snap = await _db
        .collection('employerInterests')
        .where('employerId', isEqualTo: employerId)
        .where('candidateId', isEqualTo: candidateId)
        .where('jobId', isEqualTo: jobId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Gửi thông báo quan tâm in-app cho ứng viên.
  /// Trả về `true` nếu gửi thành công, `false` nếu đã gửi trước đó.
  Future<bool> sendInterestNotification({
    required String candidateId,
    required String employerId,
    required String employerName,
    required String jobId,
    required String jobTitle,
  }) async {
    // 1. Chống spam: kiểm tra đã gửi chưa
    final alreadySent = await checkIfAlreadySent(
      employerId: employerId,
      candidateId: candidateId,
      jobId: jobId,
    );
    if (alreadySent) return false;

    // 2. Lưu lịch sử gửi quan tâm
    await _db.collection('employerInterests').add({
      'employerId': employerId,
      'candidateId': candidateId,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'employerName': employerName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Gửi thông báo in-app cho ứng viên
    try {
      final notifService = NotificationService();
      await notifService.sendToUser(
        userId: candidateId,
        title: '🌟 Nhà tuyển dụng quan tâm đến bạn!',
        body:
            '$employerName đang quan tâm đến bạn cho vị trí "$jobTitle". Nhấn để xem chi tiết công việc!',
        category: NotificationCategory.job,
        data: {
          'type': 'employer_interest',
          'jobId': jobId,
          'employerId': employerId,
          'employerName': employerName,
        },
      );
    } catch (e) {
      debugPrint('Error sending interest notification: $e');
    }

    return true;
  }
}
