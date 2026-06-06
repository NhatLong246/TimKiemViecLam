import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/models/job_post_model.dart';
import '../data/services/job_post_service.dart';
import '../data/services/wallet_service.dart';
import '../data/services/group_chat_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/schedule_lock_service.dart';
import '../routes/app_routes.dart';
import '../utils/job_time_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

  final RxSet<String> pendingDisbursementJobIds = <String>{}.obs;
  StreamSubscription<QuerySnapshot>? _noticesSubscription;
  StreamSubscription<List<JobPostModel>>? _subscription;

  // ── Tabs: Đã đăng | Chờ duyệt | Bản nháp | Quá hạn | Chờ GN | Đã HT ─────
  List<JobPostModel> get publishedPosts => allPosts.where((p) {
    if (pendingDisbursementJobIds.contains(p.jobId)) return false;
    final isPublished = p.status == 'approved' || p.status == 'active';
    final isExpired = p.exactEndTime.isBefore(DateTime.now());
    return isPublished && !isExpired;
  }).toList();

  List<JobPostModel> get pendingPosts =>
      allPosts.where((p) => p.status == 'pending').toList();

  List<JobPostModel> get draftPosts =>
      allPosts.where((p) => p.status == 'draft').toList();

  // Quá hạn: có endDate đã qua và status đang approved/active, hoặc bị từ chối (rejected)
  List<JobPostModel> get expiredPosts => allPosts
      .where(
        (p) =>
            (!pendingDisbursementJobIds.contains(p.jobId) ||
                p.filledSlots == 0) &&
            (p.status == 'rejected' ||
                (p.exactEndTime.isBefore(DateTime.now()) &&
                    (p.status == 'approved' || p.status == 'active'))),
      )
      .toList();

  // Chờ giải ngân (đang có yêu cầu giải ngân pending_admin hoặc approved và phải có nhân viên)
  List<JobPostModel> get pendingDisbursementPosts => allPosts
      .where(
        (p) => pendingDisbursementJobIds.contains(p.jobId) && p.filledSlots > 0,
      )
      .toList();

  // Đã hoàn thành (đã giải ngân xong)
  List<JobPostModel> get completedPosts =>
      allPosts.where((p) => p.status == 'closed').toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _listenToJobPosts();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _noticesSubscription?.cancel();
    super.onClose();
  }

  void _listenToJobPosts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    _listenToDisbursementNotices(uid);
    _subscription = _service
        .getJobPostsByEmployer(uid)
        .listen(
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

  void _listenToDisbursementNotices(String uid) {
    _noticesSubscription = FirebaseFirestore.instance
        .collection('disbursementNotices')
        .where('employerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snap) {
            final newSet = snap.docs
                .where((d) {
                  final s = d.data()['status'] as String? ?? '';
                  return [
                    'approved',
                    'complaints_pending',
                    'complaints_reviewed',
                  ].contains(s);
                })
                .map((d) => d.data()['jobId'] as String)
                .toSet();

            pendingDisbursementJobIds.assignAll(newSet);
            allPosts.refresh(); // Ép giao diện vẽ lại
          },
          onError: (e) {
            debugPrint('Error _listenToDisbursementNotices: $e');
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
      _showJobPostError('Lỗi', e);
      return false;
    }
  }

  void _showJobPostError(String title, Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    final needsTopUp = message.contains('Số dư tiền app không đủ');
    Get.snackbar(
      needsTopUp ? 'Cần nạp tiền app' : title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: needsTopUp ? Colors.orange : null,
      colorText: needsTopUp ? Colors.white : null,
      mainButton: needsTopUp
          ? TextButton(
              onPressed: () => Get.toNamed(AppRoutes.employerWallet),
              child: const Text(
                'Nạp tiền',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
    );
  }

  // ── Gửi duyệt (draft → pending) ───────────────────────────────────────────
  Future<void> submitForReview(String jobId) async {
    try {
      await _service.updateStatus(jobId, 'pending');
      Get.snackbar(
        'Đã gửi',
        'Bài đăng đang chờ duyệt',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      _showJobPostError('Không thể gửi duyệt', e);
    }
  }

  // ── Xóa bài đăng ─────────────────────────────────────────────────────────
  Future<void> deletePost(String jobId) async {
    try {
      await _service.deleteJobPost(jobId);
      Get.snackbar(
        'Đã xóa',
        'Bài đăng đã được xóa',
        snackPosition: SnackPosition.BOTTOM,
      );
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

  // ── Hủy bài đăng (Doanh nghiệp) ───────────────────────────────────────────
  Future<void> cancelPost(JobPostModel post) async {
    try {
      if (JobTimeHelper.hasStarted(post)) {
        throw Exception('Công việc đã bắt đầu, không thể hủy.');
      }

      final db = FirebaseFirestore.instance;
      // Lấy danh sách ứng viên hợp lệ để tính đền bù.
      final appsSnap = await db
          .collection('applications')
          .where('jobId', isEqualTo: post.jobId)
          .get();

      final acceptedApps = appsSnap.docs.where((doc) {
        final data = doc.data();
        return (data['status'] ?? '').toString() == 'accepted';
      }).toList();

      final candidateIds = appsSnap.docs
          .map((d) => d.data())
          .where(
            (data) =>
                data['status'] != 'withdrawn' &&
                data['status'] != 'rejected' &&
                data['status'] != 'cancelled',
          )
          .map((data) => (data['candidateId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final shouldCompensate =
          post.depositStatus == 'held' && post.filledSlots >= post.slots;
      final compensationPerUser = shouldCompensate && candidateIds.isNotEmpty
          ? (post.totalBudget * 0.1) / candidateIds.length
          : 0.0;

      // Xử lý đền bù / hoàn tiền
      await WalletService().processJobCancellationRefund(
        employerId: post.employerId,
        jobId: post.jobId,
        totalBudget: post.totalBudget,
        candidateIds: candidateIds,
        compensateCandidates: shouldCompensate,
      );

      // Giải tán nhóm chat nếu có
      if (post.groupChatId != null && post.groupChatId!.isNotEmpty) {
        await GroupChatService().disbandGroup(post.groupChatId!);
      }

      // Cập nhật trạng thái job và application
      final batch = db.batch();
      batch.update(db.collection('jobPosts').doc(post.jobId), {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (var doc in appsSnap.docs) {
        batch.update(doc.reference, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      final schedulesSnap = await db
          .collection('schedules')
          .where('jobId', isEqualTo: post.jobId)
          .get();
      for (final doc in schedulesSnap.docs) {
        batch.update(doc.reference, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      final scheduleLocks = ScheduleLockService();
      for (final doc in acceptedApps) {
        final data = doc.data();
        final candidateId = (data['candidateId'] ?? '').toString();
        final appId = (data['appId'] ?? doc.id).toString();
        try {
          await scheduleLocks.releaseLocksForApplication(
            candidateId: candidateId,
            appId: appId,
            job: post,
          );
        } catch (_) {}
      }

      await _notifyCandidatesJobCancelled(
        post,
        candidateIds,
        compensationPerUser,
      );

      Get.snackbar(
        'Đã hủy',
        'Bài đăng đã bị hủy thành công',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Không thể hủy',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _notifyCandidatesJobCancelled(
    JobPostModel post,
    List<String> candidateIds,
    double compensationPerUser,
  ) async {
    for (final candidateId in candidateIds) {
      try {
        await NotificationService.notifyJobCancelledToCandidate(
          candidateId: candidateId,
          jobTitle: post.title,
          employerId: post.employerId,
          jobId: post.jobId,
          compensationAmount: compensationPerUser,
        );
      } catch (_) {
        // Không để lỗi thông báo làm rollback nghiệp vụ hủy đã hoàn tất.
      }
    }
  }

  Future<bool> updatePost(JobPostModel post) async {
    try {
      await _service.updateJobPost(post);
      return true;
    } catch (e) {
      _showJobPostError('Lỗi', e);
      return false;
    }
  }

  // ── Đóng bài đăng (active → closed) ──────────────────────────────────────
  Future<void> closePost(String jobId) async {
    try {
      await _service.updateStatus(jobId, 'closed');
      Get.snackbar(
        'Đã đóng',
        'Bài đăng đã được đóng',
        snackPosition: SnackPosition.BOTTOM,
      );
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
        Get.snackbar(
          'Đã rút về nháp',
          'Bạn có thể chỉnh sửa và gửi lại sau',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Không thể cập nhật trạng thái',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }



  Future<void> extendPostDurationToDate(JobPostModel post, DateTime newEndDate) async {
    try {
      final updated = post.copyWith(endDate: newEndDate);
      await _service.updateJobPost(updated);
      final format = DateFormat('dd/MM/yyyy').format(newEndDate);
      Get.snackbar(
        'Đã gia hạn',
        'Bài đăng được gia hạn đến ngày $format',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      _showJobPostError('Không thể gia hạn', e);
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
      final reopened = post.copyWith(status: 'pending', endDate: adjustedEnd);
      await _service.updateJobPost(reopened);
      Get.snackbar(
        'Đã mở lại tuyển',
        'Bài đăng đã chuyển sang chờ duyệt',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      _showJobPostError('Không thể mở lại', e);
    }
  }
}
