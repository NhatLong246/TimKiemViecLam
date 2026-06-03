import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/application_model.dart';
import '../models/job_post_model.dart';
import 'notification_service.dart';

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
    if (candidateId == employerId) {
      throw Exception('Không thể tự ứng tuyển vào bài đăng của chính mình.');
    }
    await _assertCandidateRole(candidateId);

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
      employerId: employerId,
      status: 'pending',
      coverLetter: coverLetter,
      cvUrl: cvUrl,
    );

    await docRef.set(app.toMap());

    var jobTitle = 'Công việc';
    var candidateName = 'Ứng viên';
    try {
      final jobDoc = await _db.collection('jobPosts').doc(jobId).get();
      if (jobDoc.exists) {
        final jobData = jobDoc.data()!;
        jobTitle = (jobData['title'] ?? jobTitle).toString();
        
        // Validate schedule overlap
        final newJob = JobPostModel.fromMap(jobData);
        newJob.toMap()['jobId'] = jobId; // Ensure jobId is set if missing
        await _checkScheduleOverlap(newJob, candidateId);
      }
      
      final userDoc = await _db.collection('users').doc(candidateId).get();
      if (userDoc.exists) {
        final d = userDoc.data() ?? {};
        final combined =
            '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
        if (combined.isNotEmpty) candidateName = combined;
      }
    } catch (_) {}

    await NotificationService.notifyNewApplication(
      employerId: employerId,
      jobTitle: jobTitle,
      candidateName: candidateName,
      jobId: jobId,
      appId: docRef.id,
      candidateId: candidateId,
    );
  }

  Future<void> _checkScheduleOverlap(JobPostModel newJob, String candidateId) async {
    if (newJob.startTime == null || newJob.workHoursPerDay == null) return;
    
    final newStartParts = newJob.startTime!.split(':');
    if (newStartParts.length != 2) return;
    final newStartMin = int.parse(newStartParts[0]) * 60 + int.parse(newStartParts[1]);
    final newEndMin = newStartMin + (newJob.workHoursPerDay! * 60).round();

    final newStartDay = _startOfDay(newJob.startDate);
    final newEndDay = _startOfDay(newJob.endDate ?? newJob.startDate);

    final appsSnap = await _db.collection('applications')
        .where('candidateId', isEqualTo: candidateId)
        .get();
        
    for (final doc in appsSnap.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status == 'rejected' || status == 'canceled' || status == 'withdrawn') continue;

      final oldJobId = (doc.data()['jobId'] ?? '').toString();
      if (oldJobId == newJob.jobId) continue;

      final oldJobDoc = await _db.collection('jobPosts').doc(oldJobId).get();
      if (!oldJobDoc.exists) continue;

      final oldJobData = oldJobDoc.data()!;
      oldJobData['jobId'] = oldJobId;
      final oldJob = JobPostModel.fromMap(oldJobData);
      
      if (oldJob.startTime == null || oldJob.workHoursPerDay == null) continue;

      final oldStartDay = _startOfDay(oldJob.startDate);
      final oldEndDay = _startOfDay(oldJob.endDate ?? oldJob.startDate);

      if (newStartDay.compareTo(oldEndDay) <= 0 && newEndDay.compareTo(oldStartDay) >= 0) {
        final oldStartParts = oldJob.startTime!.split(':');
        if (oldStartParts.length != 2) continue;
        final oldStartMin = int.parse(oldStartParts[0]) * 60 + int.parse(oldStartParts[1]);
        final oldEndMin = oldStartMin + (oldJob.workHoursPerDay! * 60).round();

        if (newStartMin < oldEndMin && newEndMin > oldStartMin) {
          throw Exception('Trùng lịch với "${oldJob.title}". Bạn đã ứng tuyển ca ${oldJob.startTime} đến ${_formatTime(oldEndMin)}.');
        }
      }
    }
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  
  String _formatTime(int totalMin) {
    var min = totalMin % (24 * 60);
    final h = min ~/ 60;
    final m = min % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
