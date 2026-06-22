import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../data/models/employer_stats_model.dart';
import '../data/services/employer_stats_service.dart';

class EmployerStatsController extends GetxController {
  final _service = EmployerStatsService();

  // ── State ──────────────────────────────────────────────────────────────
  final period = StatsPeriod.month.obs;
  final startDate = Rx<DateTime>(DateTime.now().subtract(const Duration(days: 30)));
  final endDate = Rx<DateTime>(DateTime.now());
  final isCustomRange = false.obs;

  final isLoading = false.obs;
  final summary = EmployerStatsSummary.empty().obs;
  final prevSummary = EmployerStatsSummary.empty().obs;
  final chartData = <EmployerChartPoint>[].obs;
  final prevChartData = <EmployerChartPoint>[].obs;
  final insightMessage = ''.obs;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    // Mặc định: tháng hiện tại
    final now = DateTime.now();
    startDate.value = DateTime(now.year, now.month, 1);
    endDate.value = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    loadData();
  }

  // ── Public methods ─────────────────────────────────────────────────────

  Map<String, DateTime> getPreviousPeriodRange() {
    final start = startDate.value;
    final end = endDate.value;
    final diff = end.difference(start);
    
    if (isCustomRange.value) {
      return {
        'start': start.subtract(diff),
        'end': start.subtract(const Duration(seconds: 1)),
      };
    }

    switch (period.value) {
      case StatsPeriod.day:
        return {
          'start': start.subtract(const Duration(days: 1)),
          'end': end.subtract(const Duration(days: 1)),
        };
      case StatsPeriod.week:
        return {
          'start': start.subtract(const Duration(days: 7)),
          'end': end.subtract(const Duration(days: 7)),
        };
      case StatsPeriod.month:
        final prevStart = DateTime(start.year, start.month - 1, 1);
        final prevEnd = DateTime(start.year, start.month, 0, 23, 59, 59);
        return {
          'start': prevStart,
          'end': prevEnd,
        };
      case StatsPeriod.year:
        final prevStart = DateTime(start.year - 1, 1, 1);
        final prevEnd = DateTime(start.year - 1, 12, 31, 23, 59, 59);
        return {
          'start': prevStart,
          'end': prevEnd,
        };
    }
  }

  void applyFilter(StatsPeriod p, DateTime date) {
    isCustomRange.value = false;
    period.value = p;
    switch (p) {
      case StatsPeriod.day:
        startDate.value = DateTime(date.year, date.month, date.day);
        endDate.value = DateTime(date.year, date.month, date.day, 23, 59, 59);
        break;
      case StatsPeriod.week:
        final start = date.subtract(Duration(days: date.weekday - 1));
        startDate.value = DateTime(start.year, start.month, start.day);
        final end = start.add(const Duration(days: 6));
        endDate.value = DateTime(end.year, end.month, end.day, 23, 59, 59);
        break;
      case StatsPeriod.month:
        startDate.value = DateTime(date.year, date.month, 1);
        endDate.value = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
        break;
      case StatsPeriod.year:
        startDate.value = DateTime(date.year, 1, 1);
        endDate.value = DateTime(date.year, 12, 31, 23, 59, 59);
        break;
    }
    loadData();
  }

  void applyCustomRange(DateTime start, DateTime end) {
    isCustomRange.value = true;
    startDate.value = DateTime(start.year, start.month, start.day);
    endDate.value = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final diff = end.difference(start).inDays;
    if (diff <= 14) {
      period.value = StatsPeriod.day;
    } else if (diff <= 90) {
      period.value = StatsPeriod.week;
    } else if (diff <= 365 * 2) {
      period.value = StatsPeriod.month;
    } else {
      period.value = StatsPeriod.year;
    }
    loadData();
  }

  void setPeriod(StatsPeriod p) {
    isCustomRange.value = false;
    period.value = p;
    _adjustDateRange(p);
    loadData();
  }

  void setDateRange(DateTime s, DateTime e) {
    isCustomRange.value = true;
    startDate.value = s;
    endDate.value = e;
    loadData();
  }

  Future<void> loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    isLoading.value = true;
    try {
      final prevRange = getPreviousPeriodRange();
      final results = await Future.wait([
        _service.fetchSummary(
          employerId: uid,
          start: startDate.value,
          end: endDate.value,
        ),
        _service.fetchChartData(
          employerId: uid,
          start: startDate.value,
          end: endDate.value,
          period: period.value,
        ),
        _service.fetchSummary(
          employerId: uid,
          start: prevRange['start']!,
          end: prevRange['end']!,
        ),
        _service.fetchChartData(
          employerId: uid,
          start: prevRange['start']!,
          end: prevRange['end']!,
          period: period.value,
        ),
      ]);
      summary.value = results[0] as EmployerStatsSummary;
      chartData.value = results[1] as List<EmployerChartPoint>;
      prevSummary.value = results[2] as EmployerStatsSummary;
      prevChartData.value = results[3] as List<EmployerChartPoint>;
      _generateInsight(summary.value);
    } finally {
      isLoading.value = false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  void _generateInsight(EmployerStatsSummary s) {
    if (s.approvedPosts == 0 && s.totalDeposited == 0) {
      insightMessage.value = "Kỳ này bạn chưa có hoạt động nào. Hãy tạo thêm tin tuyển dụng để tìm kiếm ứng viên nhé!";
      return;
    }
    
    if (s.totalHired > 0) {
      insightMessage.value = "Tuyệt vời! 🎉 Bạn đã tuyển được ${s.totalHired} nhân sự trong kỳ này. Hệ thống đang giúp bạn tiếp cận ứng viên rất hiệu quả.";
      return;
    }

    if (s.approvedPosts > 0 && s.totalHired == 0) {
      insightMessage.value = "Bạn có ${s.approvedPosts} bài đăng nhưng chưa thuê được ai. Hãy thử xem lại mức lương để thu hút thêm ứng viên nhé!";
      return;
    }
    
    if (s.totalDeposited > 0 && s.totalSpent == 0) {
      insightMessage.value = "Bạn đã nạp ${formatVnd(s.totalDeposited)} nhưng chưa chi tiêu. Tạo tin tuyển dụng ngay để bắt đầu tìm người!";
      return;
    }

    insightMessage.value = "Mọi thứ đang hoạt động ổn định. Hãy duy trì tin đăng để luôn có nguồn ứng viên dồi dào.";
  }

  void _adjustDateRange(StatsPeriod p) {
    final now = DateTime.now();
    switch (p) {
      case StatsPeriod.day:
        startDate.value = DateTime(now.year, now.month, now.day);
        endDate.value = now;
        break;
      case StatsPeriod.week:
        final weekday = now.weekday; // 1=Mon
        startDate.value = now.subtract(Duration(days: weekday - 1));
        endDate.value = now;
        break;
      case StatsPeriod.month:
        startDate.value = DateTime(now.year, now.month, 1);
        endDate.value = DateTime(now.year, now.month + 1, 0);
        break;
      case StatsPeriod.year:
        startDate.value = DateTime(now.year, 1, 1);
        endDate.value = DateTime(now.year, 12, 31);
        break;
    }
  }

  // Tiện ích hiển thị tiền VND
  String formatVnd(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M₫';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K₫';
    }
    return '${amount.toStringAsFixed(0)}₫';
  }
}
