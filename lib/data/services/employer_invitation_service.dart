import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/job_time_helper.dart';
import '../models/job_post_model.dart';
import 'candidates_service.dart';
import 'schedule_lock_service.dart';

class EmployerInvitationAcceptanceResult {
  final String applicationId;
  final String employerId;
  final JobPostModel job;
  final bool newlyAccepted;

  const EmployerInvitationAcceptanceResult({
    required this.applicationId,
    required this.employerId,
    required this.job,
    required this.newlyAccepted,
  });
}

class EmployerInvitationPolicy {
  EmployerInvitationPolicy._();

  static String? rejectionReason(JobPostModel job, {required DateTime now}) {
    if (job.status != 'approved' && job.status != 'active') {
      return 'Công việc hiện không còn nhận ứng viên.';
    }
    final deadline = job.applicationDeadline;
    if (deadline != null && !now.isBefore(deadline)) {
      return 'Lời mời đã quá hạn ứng tuyển.';
    }
    if (JobTimeHelper.hasStarted(job, now: now)) {
      return job.isFullTimeReferral
          ? 'Đã qua ngày/giờ hẹn phỏng vấn.'
          : 'Công việc đã bắt đầu.';
    }
    if (job.slots <= 0 || job.filledSlots >= job.slots) {
      return 'Công việc đã đủ số lượng ứng viên.';
    }
    return null;
  }
}

/// Nhận lời mời trực tiếp từ NTD.
///
/// Luồng này chủ động bỏ qua yêu cầu hồ sơ vì NTD đã chọn ứng viên, nhưng vẫn
/// bắt buộc kiểm tra lời mời, công việc, số chỗ và lịch làm trong transaction.
class EmployerInvitationService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final ScheduleLockService _scheduleLocks;

  EmployerInvitationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ScheduleLockService? scheduleLocks,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _scheduleLocks = scheduleLocks ?? ScheduleLockService();

  Future<EmployerInvitationAcceptanceResult> acceptInvitation({
    String? requestId,
    required String jobId,
    required String expectedEmployerId,
  }) async {
    final candidateId = _auth.currentUser?.uid;
    if (candidateId == null || candidateId.isEmpty) {
      throw Exception('Phiên đăng nhập đã hết hạn.');
    }
    if (jobId.isEmpty || expectedEmployerId.isEmpty) {
      throw Exception('Lời mời làm việc không còn đủ thông tin.');
    }

    final invitationRef = await _resolveInvitationRef(
      requestId: requestId,
      candidateId: candidateId,
      jobId: jobId,
      employerId: expectedEmployerId,
    );
    final existingApplicationRef = await _findExistingApplicationRef(
      candidateId: candidateId,
      jobId: jobId,
    );
    final applicationRef =
        existingApplicationRef ?? _db.collection('applications').doc();
    final jobRef = _db.collection('jobPosts').doc(jobId);
    final candidateRef = _db.collection('users').doc(candidateId);

    final transactionResult = await _db
        .runTransaction<_InvitationTransactionResult>((tx) async {
      final invitationSnap = await tx.get(invitationRef);
      final jobSnap = await tx.get(jobRef);
      final candidateSnap = await tx.get(candidateRef);
      final applicationSnap = await tx.get(applicationRef);

      if (!invitationSnap.exists) {
        throw Exception('Lời mời làm việc không còn tồn tại.');
      }
      if (!jobSnap.exists) throw Exception('Công việc không còn tồn tại.');
      if (!candidateSnap.exists) {
        throw Exception('Không tìm thấy hồ sơ ứng viên.');
      }

      final invitationData = invitationSnap.data() ?? {};
      final jobData = jobSnap.data() ?? {};
      final candidateData = candidateSnap.data() ?? {};
      final applicationData = applicationSnap.data() ?? {};

      final invitationCandidateId =
          (invitationData['candidateId'] ?? '').toString();
      final invitationJobId = (invitationData['jobId'] ?? '').toString();
      final invitationEmployerId =
          (invitationData['employerId'] ?? '').toString();
      final authoritativeEmployerId =
          (jobData['employerId'] ?? '').toString();

      if (invitationCandidateId != candidateId ||
          invitationJobId != jobId ||
          invitationEmployerId != expectedEmployerId ||
          authoritativeEmployerId != invitationEmployerId) {
        throw Exception('Lời mời không khớp với ứng viên hoặc bài đăng.');
      }
      if ((candidateData['role'] ?? 'candidate').toString() != 'candidate') {
        throw Exception('Chỉ tài khoản ứng viên mới được nhận công việc.');
      }
      if (candidateData['isActive'] == false) {
        throw Exception('Tài khoản ứng viên hiện không hoạt động.');
      }

      final applicationStatus =
          (applicationData['status'] ?? '').toString();
      if (applicationSnap.exists) {
        if ((applicationData['candidateId'] ?? '').toString() != candidateId ||
            (applicationData['jobId'] ?? '').toString() != jobId ||
            ((applicationData['employerId'] ?? '').toString().isNotEmpty &&
                (applicationData['employerId'] ?? '').toString() !=
                    authoritativeEmployerId)) {
          throw Exception('Đơn ứng tuyển hiện tại không hợp lệ.');
        }
      }

      final invitationStatus =
          (invitationData['status'] ?? 'pending').toString();
      jobData['jobId'] = jobSnap.id;
      final acceptedJob = JobPostModel.fromMap(jobData);

      if (applicationStatus == 'accepted') {
        if (invitationStatus == 'pending') {
          tx.update(invitationRef, {
            'status': 'accepted',
            'applicationId': applicationRef.id,
            'respondedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (invitationStatus != 'accepted') {
          throw Exception('Lời mời đã được xử lý trước đó.');
        }
        return _InvitationTransactionResult(
          job: acceptedJob,
          employerId: authoritativeEmployerId,
          newlyAccepted: false,
        );
      }
      if (invitationStatus != 'pending') {
        throw Exception('Lời mời đã được xử lý hoặc không còn hiệu lực.');
      }

      final now = DateTime.now();
      if (jobData['startDate'] == null) {
        throw Exception('Công việc thiếu ngày bắt đầu hoặc lịch phỏng vấn.');
      }
      final rejectionReason = EmployerInvitationPolicy.rejectionReason(
        acceptedJob,
        now: now,
      );
      if (rejectionReason != null) throw Exception(rejectionReason);
      if (applicationSnap.exists &&
          applicationStatus != 'pending' &&
          applicationStatus != 'rejected' &&
          applicationStatus != 'withdrawn') {
        throw Exception('Đơn ứng tuyển hiện tại không thể được chấp nhận.');
      }

      if (!acceptedJob.isFullTimeReferral) {
        await _scheduleLocks.acquireLocksInTransaction(
          tx: tx,
          candidateId: candidateId,
          appId: applicationRef.id,
          jobId: jobId,
          employerId: authoritativeEmployerId,
          jobTitle: acceptedJob.title,
          windows: ScheduleLockService.buildShiftWindows(acceptedJob),
        );
      }

      final applicationWrite = <String, dynamic>{
        'appId': applicationRef.id,
        'jobId': jobId,
        'candidateId': candidateId,
        'employerId': authoritativeEmployerId,
        'status': 'accepted',
        'source': 'employer_invitation',
        'hireRequestId': invitationRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!applicationSnap.exists || applicationData['appliedAt'] == null) {
        applicationWrite['appliedAt'] = FieldValue.serverTimestamp();
      }

      tx.set(applicationRef, applicationWrite, SetOptions(merge: true));
      tx.update(jobRef, {
        'filledSlots': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(invitationRef, {
        'status': 'accepted',
        'applicationId': applicationRef.id,
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return _InvitationTransactionResult(
        job: acceptedJob,
        employerId: authoritativeEmployerId,
        newlyAccepted: true,
      );
    });

    if (transactionResult.newlyAccepted) {
      try {
        await CandidatesService().completeAcceptedApplication(
          appId: applicationRef.id,
          acceptedJob: transactionResult.job,
          candidateId: candidateId,
          employerId: transactionResult.employerId,
        );
      } catch (_) {
        // Dữ liệu nhận việc đã commit; hiệu ứng phụ có thể được làm mới sau.
      }
    }

    return EmployerInvitationAcceptanceResult(
      applicationId: applicationRef.id,
      employerId: transactionResult.employerId,
      job: transactionResult.job,
      newlyAccepted: transactionResult.newlyAccepted,
    );
  }

  Future<DocumentReference<Map<String, dynamic>>> _resolveInvitationRef({
    String? requestId,
    required String candidateId,
    required String jobId,
    required String employerId,
  }) async {
    final normalizedRequestId = requestId?.trim() ?? '';
    if (normalizedRequestId.isNotEmpty) {
      return _db.collection('employerInterests').doc(normalizedRequestId);
    }

    final snap = await _db
        .collection('employerInterests')
        .where('candidateId', isEqualTo: candidateId)
        .get(const GetOptions(source: Source.server));
    for (final doc in snap.docs) {
      final data = doc.data();
      final matches = data['jobId']?.toString() == jobId &&
          data['employerId']?.toString() == employerId &&
          (data['status'] ?? 'pending').toString() == 'pending';
      if (matches) return doc.reference;
    }
    throw Exception('Không tìm thấy lời mời đang chờ xử lý.');
  }

  Future<DocumentReference<Map<String, dynamic>>?>
  _findExistingApplicationRef({
    required String candidateId,
    required String jobId,
  }) async {
    final snap = await _db
        .collection('applications')
        .where('candidateId', isEqualTo: candidateId)
        .get(const GetOptions(source: Source.server));
    final matching = snap.docs
        .where((doc) => doc.data()['jobId']?.toString() == jobId)
        .toList();
    if (matching.isEmpty) return null;

    int priority(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return switch ((doc.data()['status'] ?? '').toString()) {
        'accepted' => 0,
        'pending' => 1,
        'rejected' => 2,
        'withdrawn' => 3,
        _ => 4,
      };
    }

    matching.sort((a, b) => priority(a).compareTo(priority(b)));
    return matching.first.reference;
  }
}

class _InvitationTransactionResult {
  final JobPostModel job;
  final String employerId;
  final bool newlyAccepted;

  const _InvitationTransactionResult({
    required this.job,
    required this.employerId,
    required this.newlyAccepted,
  });
}
