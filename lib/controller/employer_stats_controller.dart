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

  final isLoading = false.obs;
  final summary = EmployerStatsSummary.empty().obs;
  final chartData = <EmployerChartPoint>[].obs;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    // Mặc định: tháng hiện tại
    final now = DateTime.now();
    startDate.value = DateTime(now.year, now.month, 1);
    endDate.value = DateTime(now.year, now.month + 1, 0);
    loadData();
  }

  // ── Public methods ─────────────────────────────────────────────────────

  void setPeriod(StatsPeriod p) {
    period.value = p;
    _adjustDateRange(p);
    loadData();
  }

  void setDateRange(DateTime s, DateTime e) {
    startDate.value = s;
    endDate.value = e;
    loadData();
  }

  Future<void> loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    isLoading.value = true;
    try {
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
      ]);
      summary.value = results[0] as EmployerStatsSummary;
      chartData.value = results[1] as List<EmployerChartPoint>;
    } finally {
      isLoading.value = false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

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
