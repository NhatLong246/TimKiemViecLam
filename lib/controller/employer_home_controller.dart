import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../data/models/job_post_model.dart';
import '../data/services/job_post_service.dart';
import 'candidates_controller.dart';

class EmployerHomeController extends GetxController {
  final _postService = JobPostService();

  final RxList<JobPostModel> posts = <JobPostModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxInt displayCount = 3.obs;

  StreamSubscription<List<JobPostModel>>? _sub;
  Completer<void>? _pendingFirstEvent;

  @override
  void onInit() {
    super.onInit();
    _listenToPosts();
  }

  @override
  void onClose() {
    _finishPendingFirstEvent();
    _sub?.cancel();
    super.onClose();
  }

  Future<void> _listenToPosts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }
    _finishPendingFirstEvent();
    await _sub?.cancel();
    isLoading.value = true;
    final firstEvent = Completer<void>();
    _pendingFirstEvent = firstEvent;
    _sub = _postService
        .getJobPostsByEmployer(uid)
        .listen(
          (allPosts) {
            // Chỉ lưu các bài đăng có status đã biết (loại draft + bất kỳ status lạ nào)
            const knownStatuses = {
              'pending',
              'approved',
              'active',
              'closed',
              'rejected',
              'cancelled',
              'deleted',
            };
            posts.value = allPosts
                .where((p) => knownStatuses.contains(p.status))
                .toList();
            isLoading.value = false;
            _completeFirstEvent(firstEvent);
          },
          onError: (_) {
            isLoading.value = false;
            _completeFirstEvent(firstEvent);
          },
        );
    return firstEvent.future;
  }

  void _completeFirstEvent(Completer<void> firstEvent) {
    if (!firstEvent.isCompleted) firstEvent.complete();
    if (identical(_pendingFirstEvent, firstEvent)) {
      _pendingFirstEvent = null;
    }
  }

  void _finishPendingFirstEvent() {
    final pending = _pendingFirstEvent;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
    _pendingFirstEvent = null;
  }

  Future<void> refreshHome() async {
    displayCount.value = 3;
    await _listenToPosts();
    if (Get.isRegistered<CandidatesController>()) {
      await Get.find<CandidatesController>().loadAll();
    }
  }

  // ── Thống kê ────────────────────────────────────────────────────────
  int get activePostsCount =>
      posts.where((p) => p.status == 'approved' || p.status == 'active').length;

  int get totalHired => posts.fold(0, (sum, p) => sum + p.filledSlots);

  // ── Bài đăng "đang hoạt động / tương lai" (hiển thị trang chủ) ─────
  /// Chỉ bao gồm CÁC STATUS CỤ THỂ: pending, approved, active
  /// và closed nếu endDate còn trong tương lai.
  /// Mọi status khác (draft, empty, unknown) đều bị ẩn.
  List<JobPostModel> get activePosts {
    final now = DateTime.now();
    return posts.where((p) {
      switch (p.status) {
        case 'pending':
        case 'approved':
        case 'active':
          return true;
        case 'closed':
          // Chỉ hiển thị nếu endDate còn trong tương lai
          if (p.endDate == null) {
            return false; // closed không có endDate → lịch sử
          }
          return p.endDate!.isAfter(now);
        default:
          return false; // rejected, draft, hoặc bất kỳ status lạ nào → ẩn
      }
    }).toList();
  }

  // ── Lịch sử: bài đã làm xong ───────────────
  List<JobPostModel> get completedWorkPosts {
    final now = DateTime.now();
    return posts.where((p) {
      final statusOk =
          p.status == 'approved' ||
          p.status == 'active' ||
          p.status == 'closed';
      final workEnded =
          p.status == 'closed' ||
          (p.endDate != null && !_endDateTime(p).isAfter(now));
      return statusOk && p.filledSlots > 0 && workEnded;
    }).toList();
  }

  // ── Lịch sử: bài đã hủy do không đủ người hoặc doanh nghiệp chủ động xóa ──
  List<JobPostModel> get removedPosts => posts.where((p) {
    final cancelledUnderfilled =
        p.status == 'cancelled' && p.filledSlots < p.slots;
    return cancelledUnderfilled || p.status == 'deleted';
  }).toList();

  List<JobPostModel> get completedPosts => [
    ...completedWorkPosts,
    ...removedPosts,
  ];

  DateTime _endDateTime(JobPostModel post) {
    final date = post.endDate ?? post.startDate;
    final time = post.startTime?.trim();
    if (time == null || time.isEmpty) {
      return DateTime(date.year, date.month, date.day, 23, 59, 59);
    }

    final parts = time.split(':');
    if (parts.length != 2) {
      return DateTime(date.year, date.month, date.day, 23, 59, 59);
    }

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final workHours = post.workHoursPerDay ?? 0;
    final start = DateTime(date.year, date.month, date.day, hour, minute);
    if (workHours <= 0) {
      return DateTime(date.year, date.month, date.day, 23, 59, 59);
    }
    return start.add(Duration(minutes: (workHours * 60).round()));
  }

  // ── Phân trang (dùng activePosts thay vì toàn bộ posts) ─────────────
  List<JobPostModel> get displayedPosts =>
      activePosts.take(displayCount.value).toList();

  bool get hasMore => activePosts.length > displayCount.value;

  void loadMore() => displayCount.value += 3;
}
