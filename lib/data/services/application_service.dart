import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/application_model.dart';
import '../models/job_post_model.dart';
import '../../utils/job_time_helper.dart';
import 'notification_service.dart';
import 'schedule_service.dart';

class ApplicationService {
  final _db = FirebaseFirestore.instance;

  Future<void> _assertCandidateRole(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final role = (userDoc.data()?['role'] ?? 'candidate').toString();
    if (role != 'candidate') {
      throw Exception('Chỉ tài khoản ứng viên mới được ứng tuyển.');
    }
  }

  /// Tạo đơn ứng tuyển mới
  Future<void> applyForJob({
    required String jobId,
    required String employerId,
    required String candidateId,
    String? coverLetter,
    String? cvUrl,
  }) async {
    await _assertCandidateRole(candidateId);

    final jobDoc = await _db.collection('jobPosts').doc(jobId).get();
    if (!jobDoc.exists) {
      throw Exception('Công việc không tồn tại.');
    }
    final jobData = jobDoc.data() ?? {};
    final jobEmployerId = (jobData['employerId'] ?? employerId).toString();
    if (candidateId == jobEmployerId) {
      throw Exception('Không thể tự ứng tuyển vào bài đăng của chính mình.');
    }

    final status = (jobData['status'] ?? '').toString();
    if (status != 'approved' && status != 'active') {
      throw Exception('Công việc hiện không nhận ứng tuyển.');
    }

    final now = DateTime.now();
    final startDate = (jobData['startDate'] as Timestamp?)?.toDate();
    if (startDate == null) {
      throw Exception('Công việc thiếu ngày bắt đầu.');
    }
    final startAt = JobTimeHelper.combineDateAndTime(
      startDate,
      jobData['startTime'] as String?,
    );
    if (!now.isBefore(startAt)) {
      throw Exception('Công việc đã bắt đầu, không thể ứng tuyển.');
    }

    final deadline = (jobData['applicationDeadline'] as Timestamp?)?.toDate();
    if (deadline != null && !now.isBefore(deadline)) {
      throw Exception('Đã hết hạn ứng tuyển công việc này.');
    }

    final slots = (jobData['slots'] as num?)?.toInt() ?? 0;
    final filledSlots = (jobData['filledSlots'] as num?)?.toInt() ?? 0;
    if (slots <= 0 || filledSlots >= slots) {
      throw Exception('Công việc đã đủ số lượng ứng viên.');
    }

    jobData['jobId'] = jobDoc.id;
    final jobModel = JobPostModel.fromMap(jobData);

    final scheduleService = ScheduleService();
    await scheduleService.checkOverlap(candidateId, jobModel);

    // Check duplicate: candidateId + jobId
    final duplicateCheck = await _db
        .collection('applications')
        .where('jobId', isEqualTo: jobId)
        .where('candidateId', isEqualTo: candidateId)
        .get();

    if (duplicateCheck.docs.isNotEmpty) {
      throw Exception('Bạn đã ứng tuyển công việc này rồi!');
    }

    final docRef = _db.collection('applications').doc();
    final app = ApplicationModel(
      appId: docRef.id,
      jobId: jobId,
      candidateId: candidateId,
      employerId: jobEmployerId,
      status: 'pending',
      coverLetter: coverLetter,
      cvUrl: cvUrl,
    );

    await docRef.set(app.toMap());

    var jobTitle = jobModel.title;
    var candidateName = 'Ứng viên';
    try {
      jobTitle = (jobData['title'] ?? jobTitle).toString();
      final userDoc = await _db.collection('users').doc(candidateId).get();
      if (userDoc.exists) {
        final d = userDoc.data() ?? {};
        final combined = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'
            .trim();
        if (combined.isNotEmpty) candidateName = combined;
      }
    } catch (_) {}

    await NotificationService.notifyNewApplication(
      employerId: jobEmployerId,
      jobTitle: jobTitle,
      candidateName: candidateName,
      jobId: jobId,
      appId: docRef.id,
      candidateId: candidateId,
    );
  }
}
