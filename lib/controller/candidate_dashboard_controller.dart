import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../data/models/candidate_dashboard_models.dart';
import '../data/models/employer_stats_model.dart';
import '../data/services/candidate_dashboard_service.dart';
import 'login_controller.dart';

class CandidateDashboardController extends GetxController {
  final CandidateDashboardService _service = CandidateDashboardService();

  final payments = <CandidatePayment>[].obs;
  final reviews = <CandidateReviewGiven>[].obs;
  final reviewsReceived = <CandidateReviewGiven>[].obs;
  final reviewableJobs = <ReviewableJob>[].obs;
  final groups = <WorkGroup>[].obs;
  final summary = Rxn<CandidateEarningsSummary>();
  final isLoading = false.obs;
  final isWithdrawing = false.obs;
  final errorMessage = ''.obs;
  final insightMessage = ''.obs;

  final period = StatsPeriod.month.obs;
  final startDate = Rx<DateTime>(DateTime.now().subtract(const Duration(days: 30)));
  final endDate = Rx<DateTime>(DateTime.now());
  final chartData = <CandidateChartPoint>[].obs;

  @override
  void onInit() {
    super.onInit();
    _updateDateRangeFromPeriod(StatsPeriod.month);
  }

  double get profileRating {
    final user = Get.find<AuthController>().currentUser;
    return user?.averageRating ?? 0;
  }

  Future<void> loadBenefits() async {
    await _load(() async {
      payments.assignAll(await _service.fetchPayments());
      final s = await _service.fetchSummary(
        payments: payments,
        profileRating: profileRating,
        start: startDate.value,
        end: endDate.value,
      );
      summary.value = s;
      _generateInsight(s);
      
      chartData.assignAll(await _service.fetchChartData(
        payments: payments,
        start: startDate.value,
        end: endDate.value,
        period: period.value,
      ));
    });
  }

  Future<void> loadReviews() async {
    await _load(() async {
      reviewableJobs.assignAll(await _service.fetchReviewableJobs());
      reviews.assignAll(await _service.fetchReviewsGiven());
      reviewsReceived.assignAll(await _service.fetchReviewsReceived());
    });
  }

  Future<void> loadGroups() async {
    await _load(() async {
      groups.assignAll(await _service.fetchWorkGroups());
    });
  }

  Future<void> submitReview({
    required String jobId,
    required String employerId,
    required double rating,
    String? comment,
    List<String> tags = const [],
  }) async {
    await _service.submitReview(
      jobId: jobId,
      employerId: employerId,
      rating: rating,
      comment: comment,
      tags: tags,
    );
    await loadReviews();
  }

  Future<WorkGroup> createGroup(String name) async {
    final g = await _service.createGroup(name);
    await loadGroups();
    return g;
  }

  Future<WorkGroup> joinGroup(String code) async {
    final g = await _service.joinGroup(code);
    await loadGroups();
    return g;
  }

  Future<void> withdraw({required int amountVnd, String? note}) async {
    isWithdrawing.value = true;
    try {
      await _service.withdraw(amountVnd: amountVnd, note: note);
      await loadBenefits();
    } finally {
      isWithdrawing.value = false;
    }
  }

  void _generateInsight(CandidateEarningsSummary s) {
    if (s.periodPaidVnd == 0 && s.pendingVnd == 0) {
      insightMessage.value = "Kỳ này bạn chưa có thu nhập nào. Hãy tích cực tìm kiếm công việc mới để tăng thu nhập nhé!";
      return;
    }
    
    if (s.periodPaidVnd > 0) {
      insightMessage.value = "Tuyệt vời! 🎉 Kỳ này bạn đã kiếm được ${s.formatVnd(s.periodPaidVnd)} từ ${s.jobCount} ca làm. Hãy tiếp tục phát huy!";
      return;
    }

    if (s.pendingVnd > 0 && s.periodPaidVnd == 0) {
      insightMessage.value = "Bạn đang có ${s.formatVnd(s.pendingVnd)} đang chờ duyệt. Đánh giá tốt sẽ giúp bạn nhận lương nhanh hơn!";
      return;
    }

    insightMessage.value = "Mọi thứ đang rất tốt, điểm uy tín của bạn là ${s.avgRating.toStringAsFixed(1)}⭐. Hãy duy trì phong độ làm việc!";
  }

  Future<void> _load(Future<void> Function() action) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await action();
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  void updatePeriod(StatsPeriod p) {
    period.value = p;
    _updateDateRangeFromPeriod(p);
    loadBenefits();
  }

  void _updateDateRangeFromPeriod(StatsPeriod p) {
    final now = DateTime.now();
    switch (p) {
      case StatsPeriod.day:
        startDate.value = now.subtract(const Duration(days: 7));
        endDate.value = now;
        break;
      case StatsPeriod.week:
        startDate.value = now.subtract(const Duration(days: 28));
        endDate.value = now;
        break;
      case StatsPeriod.month:
        startDate.value = DateTime(now.year, now.month - 5, 1);
        endDate.value = DateTime(now.year, now.month + 1, 0);
        break;
      case StatsPeriod.year:
        startDate.value = DateTime(now.year - 4, 1, 1);
        endDate.value = DateTime(now.year, 12, 31);
        break;
    }
  }

  Future<void> pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: startDate.value,
        end: endDate.value,
      ),
    );
    if (picked != null) {
      startDate.value = picked.start;
      endDate.value = picked.end;
      final diff = picked.end.difference(picked.start).inDays;
      if (diff <= 14) {
        period.value = StatsPeriod.day;
      } else if (diff <= 90) {
        period.value = StatsPeriod.week;
      } else if (diff <= 365 * 2) {
        period.value = StatsPeriod.month;
      } else {
        period.value = StatsPeriod.year;
      }
      loadBenefits();
    }
  }
}
