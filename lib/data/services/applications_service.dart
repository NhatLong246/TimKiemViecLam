import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/application_model.dart';
import 'notification_service.dart';

class ApplicationsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _assertCandidateRole(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final role = (userDoc.data()?['role'] ?? 'candidate').toString();
    if (role != 'candidate') {
      throw Exception('Chỉ tài khoản ứng viên mới được ứng tuyển.');
    }
  }

  Future<String> applyToJob({
    required String jobId,
    required String employerId,
    String? coverLetter,
    String? cvUrl,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Chưa đăng nhập');
    if (uid == employerId) {
      throw Exception('Không thể tự ứng tuyển vào bài đăng của chính mình.');
    }
    await _assertCandidateRole(uid);

    final dup = await _db
        .collection('applications')
        .where('candidateId', isEqualTo: uid)
        .where('jobId', isEqualTo: jobId)
        .limit(1)
        .get();

    if (dup.docs.isNotEmpty) {
      final status = dup.docs.first.data()['status'] as String? ?? 'pending';
      if (status == 'withdrawn' || status == 'rejected') {
        await dup.docs.first.reference.update({
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
          if (coverLetter != null) 'coverLetter': coverLetter,
          if (cvUrl != null) 'cvUrl': cvUrl,
        });
        return dup.docs.first.id;
      }
      throw Exception('Bạn đã ứng tuyển tin này');
    }

    final ref = _db.collection('applications').doc();
    final model = ApplicationModel(
      appId: ref.id,
      jobId: jobId,
      candidateId: uid,
      employerId: employerId,
      status: 'pending',
      cvUrl: cvUrl,
      coverLetter: coverLetter,
    );

    await ref.set(model.toMap());

    final jobSnap = await _db.collection('jobPosts').doc(jobId).get();
    final jobTitle = (jobSnap.data()?['title'] ?? 'Công việc').toString();

    var candidateName = 'Ứng viên';
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
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
      appId: ref.id,
      candidateId: uid,
    );

    return ref.id;
  }
}
