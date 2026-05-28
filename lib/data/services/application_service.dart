import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/application_model.dart';
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
        jobTitle = (jobDoc.data()?['title'] ?? jobTitle).toString();
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
}
