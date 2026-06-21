import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/job_criteria_model.dart';
import '../models/app_notification_model.dart';
import 'notification_service.dart';

/// Lưu thông tin ứng viên kèm tiêu chí tìm việc.
class DiscoverableCandidate {
  final UserModel user;
  final JobCriteriaModel? criteria;

  const DiscoverableCandidate({required this.user, required this.criteria});
}

/// Danh sách ứng viên cho phép NTD tìm thấy hồ sơ (`allowEmployerDiscovery: true`).
class CandidateDiscoveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// All active workers who explicitly allow employer discovery.
  Future<List<DiscoverableCandidate>> fetchPotentialCandidates({
    String? keyword,
    int limit = 50,
  }) async {
    final snap = await _db
        .collection('users')
        .where('allowEmployerDiscovery', isEqualTo: true)
        .limit(limit)
        .get();

    final query = keyword?.trim().toLowerCase() ?? '';
    final results = <DiscoverableCandidate>[];
    for (final doc in snap.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['uid'] = doc.id;
      final user = UserModel.fromMap(data);
      if (user.role != 'candidate' || !user.isActive) continue;

      final criteria = JobCriteriaModel.fromUserData(data);
      if (query.isNotEmpty) {
        final matches =
            user.fullName.toLowerCase().contains(query) ||
            user.username.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            (criteria?.position.toLowerCase().contains(query) ?? false) ||
            (criteria?.careers.any(
                  (career) => career.toLowerCase().contains(query),
                ) ??
                false);
        if (!matches) continue;
      }

      results.add(DiscoverableCandidate(user: user, criteria: criteria));
    }

    results.sort((a, b) {
      final rating = b.user.averageRating.compareTo(a.user.averageRating);
      if (rating != 0) return rating;
      final jobs = b.user.totalJobsDone.compareTo(a.user.totalJobsDone);
      if (jobs != 0) return jobs;
      return a.user.fullName.compareTo(b.user.fullName);
    });
    return results;
  }

  Future<void> recordProfileView({
    required String candidateId,
    required String employerId,
    String employerName = '',
  }) async {
    if (candidateId.isEmpty ||
        employerId.isEmpty ||
        candidateId == employerId) {
      return;
    }

    final ref = _db.collection('users').doc(candidateId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      final rawViewers = data['profileViewers'];
      final viewers = rawViewers is Map
          ? Map<String, dynamic>.from(rawViewers)
          : <String, dynamic>{};

      if (viewers.containsKey(employerId)) return;

      viewers[employerId] = {
        'employerId': employerId,
        if (employerName.trim().isNotEmpty) 'employerName': employerName.trim(),
        'viewedAt': FieldValue.serverTimestamp(),
      };

      tx.set(ref, {
        'profileViewers': viewers,
        'profileViewCount': viewers.length,
      }, SetOptions(merge: true));
    });
  }

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
      final hasFullTime = criteria.workTypes.any(
        (t) =>
            t.toLowerCase().contains('toàn thời gian') ||
            t.toLowerCase().contains('full'),
      );
      if (!hasFullTime) continue;

      final user = UserModel.fromMap(data);

      // Lọc theo keyword (tên, email, username)
      if (keyword != null && keyword.trim().isNotEmpty) {
        final q = keyword.trim().toLowerCase();
        final match =
            user.fullName.toLowerCase().contains(q) ||
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
        .where('candidateId', isEqualTo: candidateId)
        .get();
    return snap.docs.any((doc) {
      final data = doc.data();
      final sameRequest =
          data['employerId']?.toString() == employerId &&
          data['jobId']?.toString() == jobId;
      final status = (data['status'] ?? 'pending').toString();
      return sameRequest && (status == 'pending' || status == 'accepted');
    });
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
    final requestRef = _db.collection('employerInterests').doc();
    await requestRef.set({
      'requestId': requestRef.id,
      'employerId': employerId,
      'candidateId': candidateId,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'employerName': employerName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 3. Gửi thông báo in-app cho ứng viên
    try {
      final notifService = NotificationService();
      await notifService.sendToUser(
        userId: candidateId,
        title: 'Lời mời làm việc mới',
        body:
            '$employerName mời bạn làm công việc "$jobTitle". Bạn có thể chấp nhận hoặc từ chối lời mời.',
        category: NotificationCategory.job,
        data: {
          'type': 'hire_request',
          'requestId': requestRef.id,
          'jobId': jobId,
          'employerId': employerId,
          'employerName': employerName,
        },
      );
    } catch (e) {
      debugPrint('Error sending interest notification: $e');
      try {
        await requestRef.delete();
      } catch (_) {}
      rethrow;
    }

    return true;
  }

  /// Persists the worker response and supports legacy invitations without IDs.
  Future<void> markHireRequestResponded({
    String? requestId,
    required String employerId,
    required String candidateId,
    required String jobId,
    required String status,
    String? applicationId,
  }) async {
    DocumentReference<Map<String, dynamic>>? ref;
    if (requestId != null && requestId.isNotEmpty) {
      final candidateRef = _db.collection('employerInterests').doc(requestId);
      final snap = await candidateRef.get();
      if (snap.exists) ref = candidateRef;
    }

    if (ref == null) {
      final snap = await _db
          .collection('employerInterests')
          .where('candidateId', isEqualTo: candidateId)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final current = (data['status'] ?? 'pending').toString();
        final sameRequest =
            data['employerId']?.toString() == employerId &&
            data['jobId']?.toString() == jobId;
        if (sameRequest && current == 'pending') {
          ref = doc.reference;
          break;
        }
      }
    }

    if (ref == null) return;
    await ref.update({
      'status': status,
      if (applicationId != null && applicationId.isNotEmpty)
        'applicationId': applicationId,
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
