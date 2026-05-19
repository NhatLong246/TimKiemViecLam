import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/application_model.dart';

class ApplicationService {
  final _db = FirebaseFirestore.instance;

  /// Tạo đơn ứng tuyển mới
  Future<void> applyForJob({
    required String jobId,
    required String employerId,
    required String candidateId,
    String? coverLetter,
    String? cvUrl,
  }) async {
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
  }
}
