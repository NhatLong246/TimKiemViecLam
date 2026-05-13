import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../data/models/job_post_model.dart';
import '../data/services/job_post_service.dart';

class JobPostController extends GetxController {
  final JobPostService _service = JobPostService();

  // ── State ──────────────────────────────────────────────────────────────────
  final RxList<JobPostModel> allPosts = <JobPostModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  StreamSubscription<List<JobPostModel>>? _subscription;

  // ── Tabs: Đã đăng | Chờ duyệt | Bản nháp | Quá hạn ──────────────────────
  List<JobPostModel> get publishedPosts => allPosts
      .where((p) => p.status == 'approved' || p.status == 'active')
      .toList();

  List<JobPostModel> get pendingPosts =>
      allPosts.where((p) => p.status == 'pending').toList();

  List<JobPostModel> get draftPosts =>
      allPosts.where((p) => p.status == 'draft').toList();

  // Quá hạn: có endDate đã qua và status đang approved/active,
  // hoặc đã đóng (closed) hoặc bị từ chối (rejected)
  List<JobPostModel> get expiredPosts => allPosts
      .where((p) =>
          p.status == 'closed' ||
          p.status == 'rejected' ||
          (p.endDate != null &&
              p.endDate!.isBefore(DateTime.now()) &&
              (p.status == 'approved' || p.status == 'active')))
      .toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _listenToJobPosts();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _listenToJobPosts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    _subscription = _service.getJobPostsByEmployer(uid).listen(
      (posts) {
        allPosts.value = posts;
        isLoading.value = false;
      },
      onError: (e) {
        errorMessage.value = e.toString();
        isLoading.value = false;
      },
    );
  }

  // ── Tạo bài đăng ──────────────────────────────────────────────────────────
  Future<bool> createPost(JobPostModel post) async {
    try {
      await _service.createJobPost(post);
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('Lỗi', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  // ── Gửi duyệt (draft → pending) ───────────────────────────────────────────
  Future<void> submitForReview(String jobId) async {
    await _service.updateStatus(jobId, 'pending');
    Get.snackbar('Đã gửi', 'Bài đăng đang chờ duyệt',
        snackPosition: SnackPosition.BOTTOM);
  }

  // ── Xóa bài đăng (chỉ draft) ─────────────────────────────────────────────
  Future<void> deletePost(String jobId) async {
    await _service.deleteJobPost(jobId);
    Get.snackbar('Đã xóa', 'Bài đăng đã được xóa',
        snackPosition: SnackPosition.BOTTOM);
  }

  // ── Đóng bài đăng (active → closed) ──────────────────────────────────────
  Future<void> closePost(String jobId) async {
    await _service.updateStatus(jobId, 'closed');
    Get.snackbar('Đã đóng', 'Bài đăng đã được đóng',
        snackPosition: SnackPosition.BOTTOM);
  }

  // ── Cập nhật trạng thái bài đăng ─────────────────────────────────────────
  Future<void> updatePostStatus(String jobId, String status) async {
    await _service.updateStatus(jobId, status);
  }
}
