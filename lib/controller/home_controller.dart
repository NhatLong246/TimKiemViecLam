import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/job_post_model.dart';
import '../data/services/job_post_service.dart';

class HomeController extends GetxController {
  final JobPostService _jobPostService = JobPostService();

  final RxList<JobPostModel> latestJobs = <JobPostModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  // Lưu trạng thái ứng tuyển: {jobId: status (pending, accepted)} - realtime
  final RxMap<String, String> appliedJobStatus = <String, String>{}.obs;

  StreamSubscription? _applicationsSub;
  StreamSubscription? _authSub;

  @override
  void onInit() {
    super.onInit();
    // Lắng nghe thay đổi trạng thái đăng nhập
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      // Mỗi khi user đăng nhập hoặc đăng xuất -> fetch lại toàn bộ
      fetchLatestJobs();
      _listenToApplications(user?.uid);
    });
  }

  @override
  void onClose() {
    _applicationsSub?.cancel();
    _authSub?.cancel();
    super.onClose();
  }

  /// Lắng nghe realtime Firestore - mỗi khi có thay đổi sẽ tự cập nhật UI
  void _listenToApplications(String? uid) {
    _applicationsSub?.cancel();
    if (uid == null) {
      appliedJobStatus.clear();
      return;
    }

    _applicationsSub = FirebaseFirestore.instance
        .collection('applications')
        .where('candidateId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      final map = <String, String>{};
      for (var doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        // Theo dõi cả withdrawn để dashboard biết không cho ứng tuyển lại
        if (status == 'pending' || status == 'accepted' || status == 'withdrawn') {
          map[data['jobId'] as String] = status!;
        }
      }
      appliedJobStatus.assignAll(map);
      appliedJobStatus.refresh();
    }, onError: (e) {
      // ignore stream errors silently
    });
  }

  Future<void> fetchLatestJobs() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      // Chạy song song: lấy jobs và applied status cùng lúc
      final results = await Future.wait([
        _jobPostService.getLatestActiveJobs(),
        _fetchAppliedJobsOnce(),
      ]);
      // Gán jobs SAU KHI đã có trạng thái ứng tuyển để tránh nháy màu
      latestJobs.value = results[0] as List<JobPostModel>;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      errorMessage.value = msg;
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch một lần để có dữ liệu ngay khi mở app/đăng nhập
  Future<void> _fetchAppliedJobsOnce() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('applications')
          .where('candidateId', isEqualTo: uid)
          .get();
      final map = <String, String>{};
      for (var doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        // Theo dõi cả withdrawn để không cho ứng tuyển lại
        if (status == 'pending' || status == 'accepted' || status == 'withdrawn') {
          map[data['jobId'] as String] = status!;
        }
      }
      appliedJobStatus.assignAll(map);
      appliedJobStatus.refresh();
    } catch (_) {}
  }

  Future<void> refreshJobs() async {
    await fetchLatestJobs();
  }
}
