import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../data/models/job_post_model.dart';
import '../data/services/job_post_service.dart';

class EmployerHomeController extends GetxController {
  final _postService = JobPostService();

  final RxList<JobPostModel> posts = <JobPostModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxInt displayCount = 3.obs;

  StreamSubscription<List<JobPostModel>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _listenToPosts();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _listenToPosts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    _sub = _postService.getJobPostsByEmployer(uid).listen(
      (allPosts) {
        // Chỉ hiển thị bài đăng không phải bản nháp trên trang chủ
        posts.value =
            allPosts.where((p) => p.status != 'draft').toList();
        isLoading.value = false;
      },
      onError: (_) => isLoading.value = false,
    );
  }

  // ── Thống kê ────────────────────────────────────────────────────────
  int get activePostsCount => posts
      .where((p) => p.status == 'approved' || p.status == 'active')
      .length;

  int get totalHired =>
      posts.fold(0, (sum, p) => sum + p.filledSlots);

  // ── Phân trang ──────────────────────────────────────────────────────
  List<JobPostModel> get displayedPosts =>
      posts.take(displayCount.value).toList();

  bool get hasMore => posts.length > displayCount.value;

  void loadMore() => displayCount.value += 3;
}
