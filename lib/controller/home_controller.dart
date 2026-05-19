import 'package:get/get.dart';
import '../data/models/job_post_model.dart';
import '../data/services/job_post_service.dart';

class HomeController extends GetxController {
  final JobPostService _jobPostService = JobPostService();

  final RxList<JobPostModel> latestJobs = <JobPostModel>[].obs;
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
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshJobs() async {
    await fetchLatestJobs();
  }
}
