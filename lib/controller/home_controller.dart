import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/job_post_model.dart';
import '../data/services/job_post_service.dart';

class HomeController extends GetxController {
  final JobPostService _jobPostService = JobPostService();

  final RxList<JobPostModel> latestJobs = <JobPostModel>[].obs;
  final RxSet<String> appliedJobIds = <String>{}.obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchLatestJobs();
  }

  Future<void> fetchLatestJobs() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final jobs = await _jobPostService.getLatestActiveJobs();
      latestJobs.value = jobs;
      await fetchAppliedJobs();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      errorMessage.value = msg;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchAppliedJobs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('applications')
          .where('candidateId', isEqualTo: uid)
          .get();
      final newSet = snap.docs
          .map((d) => d.data()['jobId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();
      appliedJobIds.clear();
      appliedJobIds.addAll(newSet);
    } catch (e) {
      print('Lỗi fetchAppliedJobs: $e');
    }
  }

  Future<void> refreshJobs() async {
    await fetchLatestJobs();
  }
}
