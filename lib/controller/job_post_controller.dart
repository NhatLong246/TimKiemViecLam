import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/models/job_post_model.dart';
import '../data/services/job_post_service.dart';

class JobPostController extends GetxController {
  final JobPostService _service = JobPostService();
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ── State ──────────────────────────────────────────────────────────────────
  final RxList<JobPostModel> allPosts = <JobPostModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  StreamSubscription<List<JobPostModel>>? _subscription;

  // ── Tabs: Đã đăng | Chờ duyệt | Bản nháp | Quá hạn ──────────────────────
  List<JobPostModel> get publishedPosts => allPosts
      .where((p) {
        final isPublished = p.status == 'approved' || p.status == 'active';
        final isExpired = p.endDate != null &&
            DateTime(
                  p.endDate!.year,
                  p.endDate!.month,
                  p.endDate!.day,
                )
                .isBefore(_today);
        return isPublished && !isExpired;
      })
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
              DateTime(
                p.endDate!.year,
                p.endDate!.month,
                p.endDate!.day,
              ).isBefore(_today) &&
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
    try {
      await _service.updateStatus(jobId, 'pending');
      Get.snackbar('Đã gửi', 'Bài đăng đang chờ duyệt',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar(
        'Không thể gửi duyệt',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ── Xóa bài đăng ─────────────────────────────────────────────────────────
  Future<void> deletePost(String jobId) async {
    try {
      await _service.deleteJobPost(jobId);
      Get.snackbar('Đã xóa', 'Bài đăng đã được xóa',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar(
        'Không thể xóa',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  Future<bool> updatePost(JobPostModel post) async {
    try {
      await _service.updateJobPost(post);
      return true;
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
      return false;
    }
  }

  // ── Đóng bài đăng (active → closed) ──────────────────────────────────────
  Future<void> closePost(String jobId) async {
    try {
      await _service.updateStatus(jobId, 'closed');
      Get.snackbar('Đã đóng', 'Bài đăng đã được đóng',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar(
        'Không thể đóng bài đăng',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ── Cập nhật trạng thái bài đăng ─────────────────────────────────────────
  Future<void> updatePostStatus(String jobId, String status) async {
    try {
      await _service.updateStatus(jobId, status);
      if (status == 'draft') {
        Get.snackbar('Đã rút về nháp', 'Bạn có thể chỉnh sửa và gửi lại sau',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar(
        'Không thể cập nhật trạng thái',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> duplicateAsDraft(JobPostModel source) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final baseStart = source.startDate.isBefore(today) ? today : source.startDate;
      final newStart = baseStart.add(const Duration(days: 1));
      DateTime? newEnd;
      if (source.endDate != null) {
        final span = source.endDate!.difference(source.startDate).inDays;
        newEnd = newStart.add(Duration(days: span < 0 ? 0 : span));
      }

      final draft = source.copyWith(
        jobId: '',
        title: '${source.title} (Bản sao)',
        status: 'draft',
        filledSlots: 0,
        groupChatId: null,
        startDate: newStart,
        endDate: newEnd,
        createdAt: null,
        updatedAt: null,
      );

      await _service.createJobPost(draft);
      Get.snackbar(
        'Đã sao chép',
        'Đã tạo 1 bản nháp mới từ bài đăng này',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Không thể sao chép',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> extendPostDuration(JobPostModel post, {int days = 7}) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final base = (post.endDate == null || post.endDate!.isBefore(today))
          ? today
          : DateTime(post.endDate!.year, post.endDate!.month, post.endDate!.day);
      final updated = post.copyWith(endDate: base.add(Duration(days: days)));
      await _service.updateJobPost(updated);
      Get.snackbar(
        'Đã gia hạn',
        'Bài đăng được gia hạn thêm $days ngày',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Không thể gia hạn',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> reopenPost(JobPostModel post) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final end = post.endDate;
      final adjustedEnd = (end == null || end.isBefore(today))
          ? today.add(const Duration(days: 7))
          : end;
      final reopened = post.copyWith(
        status: 'pending',
        endDate: adjustedEnd,
      );
      await _service.updateJobPost(reopened);
      Get.snackbar(
        'Đã mở lại tuyển',
        'Bài đăng đã chuyển sang chờ duyệt',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Không thể mở lại',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
