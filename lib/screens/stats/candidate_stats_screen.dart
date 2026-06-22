import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/candidate_dashboard_controller.dart';
import '../../controller/login_controller.dart';
import '../../data/models/candidate_dashboard_models.dart';
import '../../data/models/employer_stats_model.dart';
import '../menu_candidate/candidate_benefits_screen.dart';
import '../../common/widgets/animated_number_text.dart';

class CandidateStatsScreen extends StatefulWidget {
  const CandidateStatsScreen({super.key});

  @override
  State<CandidateStatsScreen> createState() => _CandidateStatsScreenState();
}

class _CandidateStatsScreenState extends State<CandidateStatsScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final CandidateDashboardController _dashCtrl = Get.put(CandidateDashboardController());

  @override
  void initState() {
    super.initState();
    _dashCtrl.loadBenefits();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Báo cáo của tôi',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Thu nhập & rút tiền',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CandidateBenefitsScreen()),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
        ],
      ),
      body: Obx(() {
        if (_dashCtrl.isLoading.value && _dashCtrl.summary.value == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.candidatePrimary),
          );
        }

        final summary = _dashCtrl.summary.value;
        if (summary == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _dashCtrl.errorMessage.value.isNotEmpty
                        ? _dashCtrl.errorMessage.value
                        : 'Không tải được báo cáo',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _dashCtrl.loadBenefits,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.candidatePrimary,
                    ),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.candidatePrimary,
          onRefresh: _dashCtrl.loadBenefits,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodNote(isDark),
                const SizedBox(height: 12),
                _FilterSummaryRow(ctrl: _dashCtrl),
                const SizedBox(height: 12),
                _InsightCard(ctrl: _dashCtrl),
                _buildMainStats(summary),
                _buildSubStats(summary),
                const SizedBox(height: 16),
                _buildIncomeChart(),
                _buildHoursChart(),
                _buildHistorySection(_dashCtrl.payments),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPeriodNote(bool isDark) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dữ liệu theo khoảng thời gian đã chọn · Giờ làm tính từ điểm danh thực tế',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodLabel() {
    if (_dashCtrl.isCustomRange.value) return 'kỳ';
    switch (_dashCtrl.period.value) {
      case StatsPeriod.day:
        return 'ngày';
      case StatsPeriod.week:
        return 'tuần';
      case StatsPeriod.month:
        return 'tháng';
      case StatsPeriod.year:
        return 'năm';
    }
  }

  Widget _buildComparisonWidget({
    required double current,
    required double previous,
    required String periodLabel,
    bool isOnDarkBackground = false,
  }) {
    if (previous == 0) {
      if (current == 0) {
        return Text(
          'Không thay đổi so với $periodLabel trước',
          style: TextStyle(
            fontSize: 12,
            color: isOnDarkBackground ? Colors.white70 : Colors.grey.shade600,
          ),
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, size: 14, color: isOnDarkBackground ? Colors.lightGreenAccent : Colors.green),
          const SizedBox(width: 4),
          Text(
            'Tăng so với $periodLabel trước',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOnDarkBackground ? Colors.lightGreenAccent : Colors.green,
            ),
          ),
        ],
      );
    }

    final diffPct = ((current - previous) / previous) * 100;
    final isIncrease = diffPct >= 0;
    final sign = isIncrease ? '+' : '';
    final color = isIncrease 
        ? (isOnDarkBackground ? Colors.lightGreenAccent : Colors.green)
        : (isOnDarkBackground ? Colors.redAccent : Colors.red);
    final icon = isIncrease ? Icons.trending_up : Icons.trending_down;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$sign${diffPct.toStringAsFixed(1)}% so với $periodLabel trước',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMainStats(CandidateEarningsSummary summary) {
    final prev = _dashCtrl.prevSummary.value;
    final periodLbl = _getPeriodLabel();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.candidatePrimary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GetBuilder<AuthController>(
              init: _authController,
              builder: (controller) {
                final user = controller.currentUser;
                final displayName = (user != null && user.firstName.isNotEmpty)
                    ? user.firstName
                    : 'Bạn';
                return Text(
                  'Thu nhập kỳ này của $displayName',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            AnimatedNumberText(
              summary.periodPaidVnd.toDouble(),
              format: (v) => summary.formatVnd(v.toInt()),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            _buildComparisonWidget(
              current: summary.periodPaidVnd.toDouble(),
              previous: prev?.periodPaidVnd.toDouble() ?? 0.0,
              periodLabel: periodLbl,
              isOnDarkBackground: true,
            ),
            if (summary.totalPaidVnd != summary.periodPaidVnd || summary.pendingVnd > 0 || summary.walletBalanceVnd > 0) ...[
              const Divider(height: 24, color: Colors.white24),
            ],
            if (summary.totalPaidVnd != summary.periodPaidVnd) ...[
              Text(
                'Tổng đã giải ngân: ${summary.formatVnd(summary.totalPaidVnd)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
            ],
            if (summary.pendingVnd > 0) ...[
              Text(
                'Chờ giải ngân: ${summary.formatVnd(summary.pendingVnd)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
            ],
            if (summary.walletBalanceVnd > 0) ...[
              Text(
                'Số dư ví: ${summary.formatVnd(summary.walletBalanceVnd)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubStats(CandidateEarningsSummary summary) {
    final prev = _dashCtrl.prevSummary.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Ca đã GN',
              value: summary.jobCount.toDouble(),
              previousValue: prev?.jobCount.toDouble(),
              format: (v) => v.toInt().toString(),
              icon: Icons.work_outline,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Giờ làm',
              value: summary.hoursWorked.toDouble(),
              previousValue: prev?.hoursWorked.toDouble(),
              format: (v) => '${v.toInt()}h',
              icon: Icons.timer_outlined,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Đánh giá',
              value: summary.avgRating,
              previousValue: prev?.avgRating,
              format: (v) => v > 0 ? '${v.toStringAsFixed(1)} ⭐' : '—',
              icon: Icons.star_outline,
              color: Colors.amber,
              isRating: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required double value,
    double? previousValue,
    required String Function(double) format,
    required IconData icon,
    required Color color,
    bool isRating = false,
  }) {
    // calculate diff
    Widget? diffWidget;
    if (previousValue != null) {
      if (isRating) {
        final diff = value - previousValue;
        if (diff != 0) {
          final isInc = diff > 0;
          final sign = isInc ? '+' : '';
          final textCol = isInc ? Colors.green : Colors.red;
          diffWidget = Text(
            '$sign${diff.toStringAsFixed(1)}⭐',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textCol),
          );
        }
      } else {
        if (previousValue == 0) {
          if (value > 0) {
            diffWidget = const Text(
              'Tăng',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
            );
          }
        } else {
          final diffPct = ((value - previousValue) / previousValue) * 100;
          if (diffPct != 0) {
            final isInc = diffPct > 0;
            final sign = isInc ? '+' : '';
            final textCol = isInc ? Colors.green : Colors.red;
            diffWidget = Text(
              '$sign${diffPct.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textCol),
            );
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          AnimatedNumberText(
            value,
            format: format,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (diffWidget != null) ...[
                const SizedBox(width: 4),
                diffWidget,
              ],
            ],
          ),
        ],
      ),
    );
  }

  double _xInterval(int length) {
    if (length <= 7) return 1;
    if (length <= 15) return 2;
    return (length / 5).ceilToDouble();
  }

  String _formatYAxisVnd(double val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1).replaceFirst('.0', '')}tr';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(0)}k';
    }
    return val.toInt().toString();
  }

  Widget _buildLegendItem({required String label, required Color color, bool isDashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDashed 
              ? Row(
                  children: List.generate(
                    3,
                    (index) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        color: color,
                      ),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBarLegendItem({required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildIncomeChart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Biểu đồ thu nhập',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildLegendItem(label: 'Kỳ này', color: Colors.green),
                const SizedBox(width: 12),
                _buildLegendItem(label: 'Kỳ trước', color: Colors.grey.shade400, isDashed: true),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Thu nhập thực tế (VNĐ) nhận được theo thời gian',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Obx(() {
                final data = _dashCtrl.chartData;
                final prevData = _dashCtrl.prevChartData;
                if (data.isEmpty) {
                  return const Center(
                    child: Text('Không có dữ liệu', style: TextStyle(color: Colors.grey)),
                  );
                }

                double maxPaid = 100000;
                for (final p in data) {
                  if (p.paidVnd > maxPaid) maxPaid = p.paidVnd;
                }
                for (final p in prevData) {
                  if (p.paidVnd > maxPaid) maxPaid = p.paidVnd;
                }

                return LineChart(
                  LineChartData(
                    maxY: maxPaid * 1.25,
                    minY: 0,
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: _xInterval(data.length),
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                            
                            final interval = _xInterval(data.length).toInt();
                            if (idx % interval != 0) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                data[idx].label,
                                style: const TextStyle(fontSize: 9, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (val, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                _formatYAxisVnd(val),
                                style: const TextStyle(fontSize: 9, color: Colors.grey),
                                textAlign: TextAlign.right,
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.08),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value.paidVnd);
                        }).toList(),
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 3.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.green.withOpacity(0.12),
                        ),
                      ),
                      if (prevData.isNotEmpty)
                        LineChartBarData(
                          spots: prevData.asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(), e.value.paidVnd);
                          }).toList(),
                          isCurved: true,
                          color: Colors.grey.withOpacity(0.4),
                          barWidth: 2,
                          dashArray: [5, 5],
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursChart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Biểu đồ giờ làm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildBarLegendItem(label: 'Kỳ này', color: Colors.orange),
                const SizedBox(width: 12),
                _buildBarLegendItem(label: 'Kỳ trước', color: Colors.grey.shade300),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tổng số giờ làm việc (Giờ) theo thời gian',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Obx(() {
                final data = _dashCtrl.chartData;
                final prevData = _dashCtrl.prevChartData;
                if (data.isEmpty) {
                  return const Center(
                    child: Text('Không có dữ liệu', style: TextStyle(color: Colors.grey)),
                  );
                }

                double maxHours = 8;
                for (final p in data) {
                  if (p.hoursWorked > maxHours) maxHours = p.hoursWorked;
                }
                for (final p in prevData) {
                  if (p.hoursWorked > maxHours) maxHours = p.hoursWorked;
                }

                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxHours * 1.25,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: _xInterval(data.length),
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                            
                            final interval = _xInterval(data.length).toInt();
                            if (idx % interval != 0) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                data[idx].label,
                                style: const TextStyle(fontSize: 9, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (val, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                '${val.toInt()}h',
                                style: const TextStyle(fontSize: 9, color: Colors.grey),
                                textAlign: TextAlign.right,
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.08),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: data.asMap().entries.map((e) {
                      final idx = e.key;
                      final p = e.value;
                      final prevVal = (prevData.length > idx) ? prevData[idx].hoursWorked : 0.0;
                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: p.hoursWorked,
                            color: Colors.orange.withOpacity(0.85),
                            width: 8,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                          BarChartRodData(
                            toY: prevVal,
                            color: Colors.grey.withOpacity(0.4),
                            width: 8,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(List<CandidatePayment> payments) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lịch sử công việc đã nhận',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đã thanh toán khi NTD xác nhận giải ngân. Trạng thái khiếu nại hiển thị nếu có tranh chấp đang xử lý.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
          ),
          const SizedBox(height: 16),
          if (payments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'Chưa có công việc được NTD chấp nhận. Sau khi được duyệt và giải ngân, dữ liệu sẽ hiện tại đây.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.4),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = payments[index];
                final date = p.paidAt != null
                    ? DateFormat('dd/MM/yyyy').format(p.paidAt!)
                    : '—';
                final earningsPrefix = p.status == 'paid' ? '+ ' : '';
                final amountColor = p.status == 'paid'
                    ? const Color(0xFF2E7D32)
                    : p.status == 'disputed'
                        ? Colors.red.shade700
                        : Colors.orange.shade800;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.candidatePrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.work_outline,
                          color: AppColors.candidatePrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.jobTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$date · ${p.employerName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$earningsPrefix${p.amountDisplay}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: amountColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.ctrl});
  final CandidateDashboardController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade100, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.teal.shade200.withOpacity(0.4), blurRadius: 8),
              ],
            ),
            child: Icon(Icons.psychology, color: Colors.teal.shade600, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đánh giá thông minh',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Obx(() => Text(
                  ctrl.insightMessage.value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSummaryRow extends StatelessWidget {
  const _FilterSummaryRow({required this.ctrl});
  final CandidateDashboardController ctrl;

  String _getFilterDisplayText() {
    if (ctrl.isCustomRange.value) {
      return 'Tự chọn (${DateFormat('dd/MM/yyyy').format(ctrl.startDate.value)} - ${DateFormat('dd/MM/yyyy').format(ctrl.endDate.value)})';
    }

    final start = ctrl.startDate.value;
    final end = ctrl.endDate.value;
    final now = DateTime.now();

    switch (ctrl.period.value) {
      case StatsPeriod.day:
        final isToday = start.year == now.year && start.month == now.month && start.day == now.day;
        return isToday
            ? 'Hôm nay (${DateFormat('dd/MM').format(start)})'
            : DateFormat('dd/MM/yyyy').format(start);
      case StatsPeriod.week:
        final startOfWeekToday = now.subtract(Duration(days: now.weekday - 1));
        final isThisWeek = start.year == startOfWeekToday.year &&
            start.month == startOfWeekToday.month &&
            start.day == startOfWeekToday.day;
        final rangeStr =
            '${DateFormat('dd/MM').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}';
        return isThisWeek ? 'Tuần này ($rangeStr)' : 'Tuần ($rangeStr)';
      case StatsPeriod.month:
        final isThisMonth = start.year == now.year && start.month == now.month;
        final monthStr = 'Tháng ${start.month}/${start.year}';
        return isThisMonth ? '$monthStr (Tháng này)' : monthStr;
      case StatsPeriod.year:
        final isThisYear = start.year == now.year;
        final yearStr = 'Năm ${start.year}';
        return isThisYear ? '$yearStr (Năm này)' : yearStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final text = _getFilterDisplayText();
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đang lọc theo',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.candidatePrimary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showFilterBottomSheet(context, ctrl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.candidatePrimary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.candidatePrimary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.tune, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Lọc',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

void _showFilterBottomSheet(BuildContext context, CandidateDashboardController ctrl) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FilterBottomSheet(ctrl: ctrl),
  );
}

enum FilterMode { day, week, month, year, custom }

extension FilterModeExt on FilterMode {
  String get label {
    switch (this) {
      case FilterMode.day:
        return 'Ngày';
      case FilterMode.week:
        return 'Tuần';
      case FilterMode.month:
        return 'Tháng';
      case FilterMode.year:
        return 'Năm';
      case FilterMode.custom:
        return 'Tự chọn';
    }
  }
}

class _FilterBottomSheet extends StatefulWidget {
  const _FilterBottomSheet({required this.ctrl});
  final CandidateDashboardController ctrl;

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late FilterMode _selectedMode;
  late DateTime _selectedDate;
  late DateTime _customStart;
  late DateTime _customEnd;
  late TextEditingController _startController;
  late TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    if (widget.ctrl.isCustomRange.value) {
      _selectedMode = FilterMode.custom;
      _selectedDate = DateTime.now();
      _customStart = widget.ctrl.startDate.value;
      _customEnd = widget.ctrl.endDate.value;
    } else {
      switch (widget.ctrl.period.value) {
        case StatsPeriod.day:
          _selectedMode = FilterMode.day;
          break;
        case StatsPeriod.week:
          _selectedMode = FilterMode.week;
          break;
        case StatsPeriod.month:
          _selectedMode = FilterMode.month;
          break;
        case StatsPeriod.year:
          _selectedMode = FilterMode.year;
          break;
      }
      _selectedDate = widget.ctrl.startDate.value;
      _customStart = DateTime.now().subtract(const Duration(days: 7));
      _customEnd = DateTime.now();
    }
    _startController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(_customStart));
    _endController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(_customEnd));
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _onPeriodChanged(FilterMode mode) {
    setState(() {
      _selectedMode = mode;
      
      final now = DateTime.now();
      _selectedDate = now;
      if (mode == FilterMode.custom) {
        _customStart = now.subtract(const Duration(days: 7));
        _customEnd = now;
        _startController.text = DateFormat('dd/MM/yyyy').format(_customStart);
        _endController.text = DateFormat('dd/MM/yyyy').format(_customEnd);
      }
    });
  }

  DateTime _getStartOfPeriod(DateTime date, StatsPeriod period) {
    switch (period) {
      case StatsPeriod.day:
        return DateTime(date.year, date.month, date.day);
      case StatsPeriod.week:
        return date.subtract(Duration(days: date.weekday - 1));
      case StatsPeriod.month:
        return DateTime(date.year, date.month, 1);
      case StatsPeriod.year:
        return DateTime(date.year, 1, 1);
    }
  }

  DateTime _getEndOfPeriod(DateTime date, StatsPeriod period) {
    switch (period) {
      case StatsPeriod.day:
        return DateTime(date.year, date.month, date.day, 23, 59, 59);
      case StatsPeriod.week:
        final start = date.subtract(Duration(days: date.weekday - 1));
        return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      case StatsPeriod.month:
        return DateTime(date.year, date.month + 1, 0, 23, 59, 59);
      case StatsPeriod.year:
        return DateTime(date.year, 12, 31, 23, 59, 59);
    }
  }

  String _getSelectionLabel() {
    if (_selectedMode == FilterMode.custom) {
      return '${DateFormat('dd/MM/yyyy').format(_customStart)} - ${DateFormat('dd/MM/yyyy').format(_customEnd)}';
    }

    final statsPeriod = _selectedMode == FilterMode.day
        ? StatsPeriod.day
        : _selectedMode == FilterMode.week
            ? StatsPeriod.week
            : _selectedMode == FilterMode.month
                ? StatsPeriod.month
                : StatsPeriod.year;

    final start = _getStartOfPeriod(_selectedDate, statsPeriod);
    final end = _getEndOfPeriod(_selectedDate, statsPeriod);
    final now = DateTime.now();

    switch (statsPeriod) {
      case StatsPeriod.day:
        final isToday = start.year == now.year && start.month == now.month && start.day == now.day;
        return isToday 
            ? 'Hôm nay (${DateFormat('dd/MM/yyyy').format(start)})' 
            : DateFormat('dd/MM/yyyy').format(start);
      case StatsPeriod.week:
        final startOfWeekToday = now.subtract(Duration(days: now.weekday - 1));
        final isThisWeek = start.year == startOfWeekToday.year &&
            start.month == startOfWeekToday.month &&
            start.day == startOfWeekToday.day;
        final rangeStr = '${DateFormat('dd/MM').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}';
        return isThisWeek ? 'Tuần này ($rangeStr)' : 'Tuần ($rangeStr)';
      case StatsPeriod.month:
        final isThisMonth = start.year == now.year && start.month == now.month;
        final monthStr = 'Tháng ${start.month}/${start.year}';
        return isThisMonth ? '$monthStr (Tháng này)' : monthStr;
      case StatsPeriod.year:
        final isThisYear = start.year == now.year;
        final yearStr = 'Năm ${start.year}';
        return isThisYear ? '$yearStr (Năm này)' : yearStr;
    }
  }

  Future<void> _pickDate() async {
    if (_selectedMode == FilterMode.day) {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
        firstDate: DateTime(2020),
        lastDate: now,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.candidatePrimary,
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          _selectedDate = picked;
        });
      }
    } else if (_selectedMode == FilterMode.week) {
      _pickWeek();
    } else if (_selectedMode == FilterMode.month) {
      _pickMonth();
    } else if (_selectedMode == FilterMode.year) {
      _pickYear();
    }
  }

  void _pickYear() {
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 2020 + 1, (index) => currentYear - index);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chọn năm', style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: years.length,
              itemBuilder: (context, index) {
                final y = years[index];
                final selected = _selectedDate.year == y;
                return ListTile(
                  title: Text('Năm $y', style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                  trailing: selected ? const Icon(Icons.check, color: AppColors.candidatePrimary) : null,
                  onTap: () {
                    setState(() {
                      _selectedDate = DateTime(y, 1, 1);
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _pickMonth() {
    showDialog(
      context: context,
      builder: (context) {
        int dialogYear = _selectedDate.year;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Chọn tháng', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: dialogYear > 2020 ? () {
                          setDialogState(() {
                            dialogYear--;
                          });
                        } : null,
                      ),
                      Text('$dialogYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: dialogYear < DateTime.now().year ? () {
                          setDialogState(() {
                            dialogYear++;
                          });
                        } : null,
                      ),
                    ],
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final m = index + 1;
                    final isFuture = dialogYear == DateTime.now().year && m > DateTime.now().month;
                    final selected = _selectedDate.year == dialogYear && _selectedDate.month == m;
                    
                    return GestureDetector(
                      onTap: isFuture ? null : () {
                        setState(() {
                          _selectedDate = DateTime(dialogYear, m, 1);
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.candidatePrimary
                              : (isFuture ? Colors.grey.shade100 : Colors.grey.shade50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? AppColors.candidatePrimary : Colors.grey.shade300,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'T$m',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Colors.white
                                : (isFuture ? Colors.grey.shade400 : Colors.black87),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _pickWeek() {
    showDialog(
      context: context,
      builder: (context) {
        int dialogYear = _selectedDate.year;
        int dialogMonth = _selectedDate.month;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final weeks = _getWeeksOfMonth(dialogYear, dialogMonth);
            return AlertDialog(
              title: const Text('Chọn tuần', style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DropdownButton<int>(
                          value: dialogMonth,
                          items: List.generate(12, (index) => index + 1).map((m) {
                            return DropdownMenuItem<int>(
                              value: m,
                              child: Text('Tháng $m'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                dialogMonth = val;
                              });
                            }
                          },
                        ),
                        DropdownButton<int>(
                          value: dialogYear,
                          items: List.generate(DateTime.now().year - 2020 + 1, (index) => DateTime.now().year - index).map((y) {
                            return DropdownMenuItem<int>(
                              value: y,
                              child: Text('Năm $y'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                dialogYear = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: weeks.length,
                        itemBuilder: (context, index) {
                          final w = weeks[index];
                          final startOfWeekSel = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
                          final selected = startOfWeekSel.year == w.start.year &&
                              startOfWeekSel.month == w.start.month &&
                              startOfWeekSel.day == w.start.day;
                              
                          return ListTile(
                            title: Text(w.label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                            trailing: selected ? const Icon(Icons.check, color: AppColors.candidatePrimary) : null,
                            onTap: () {
                              setState(() {
                                _selectedDate = w.start;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _customStart : _customEnd,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.candidatePrimary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStart = picked;
          _startController.text = DateFormat('dd/MM/yyyy').format(picked);
          if (_customStart.isAfter(_customEnd)) {
            _customEnd = _customStart;
            _endController.text = DateFormat('dd/MM/yyyy').format(_customEnd);
          }
        } else {
          _customEnd = picked;
          _endController.text = DateFormat('dd/MM/yyyy').format(picked);
          if (_customEnd.isBefore(_customStart)) {
            _customStart = _customEnd;
            _startController.text = DateFormat('dd/MM/yyyy').format(_customStart);
          }
        }
      });
    }
  }

  void _onStartTextChanged(String val) {
    try {
      final parsed = DateFormat('dd/MM/yyyy').parseStrict(val);
      if (parsed.year >= 2020 && parsed.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
        setState(() {
          _customStart = parsed;
          if (_customStart.isAfter(_customEnd)) {
            _customEnd = _customStart;
            _endController.text = DateFormat('dd/MM/yyyy').format(_customEnd);
          }
        });
      }
    } catch (_) {
      // Ignore format exception during typing
    }
  }

  void _onEndTextChanged(String val) {
    try {
      final parsed = DateFormat('dd/MM/yyyy').parseStrict(val);
      if (parsed.year >= 2020 && parsed.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
        setState(() {
          _customEnd = parsed;
          if (_customEnd.isBefore(_customStart)) {
            _customStart = _customEnd;
            _startController.text = DateFormat('dd/MM/yyyy').format(_customStart);
          }
        });
      }
    } catch (_) {
      // Ignore format exception during typing
    }
  }

  Widget _buildCustomDateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onIconTap,
    required ValueChanged<String> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.candidatePrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade400 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.datetime,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            hintText: 'dd/MM/yyyy',
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            filled: true,
            fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            suffixIcon: IconButton(
              icon: Icon(Icons.calendar_today_outlined, size: 16, color: primaryColor),
              onPressed: onIconTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bộ lọc thống kê',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn loại thời gian',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          // Custom segmented control for periods
          Container(
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: FilterMode.values.map((p) {
                final selected = _selectedMode == p;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onPeriodChanged(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.candidatePrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_selectedMode == FilterMode.custom) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildCustomDateField(
                    label: 'Từ ngày',
                    controller: _startController,
                    onIconTap: () => _pickCustomDate(true),
                    onChanged: _onStartTextChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCustomDateField(
                    label: 'Đến ngày',
                    controller: _endController,
                    onIconTap: () => _pickCustomDate(false),
                    onChanged: _onEndTextChanged,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          // Selected Value card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khoảng thời gian đang chọn',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _getSelectionLabel(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (_selectedMode != FilterMode.custom)
                      TextButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.candidatePrimary),
                        label: Text(
                          _selectedMode == FilterMode.day
                              ? 'Chọn ngày khác'
                              : _selectedMode == FilterMode.week
                                  ? 'Chọn tuần khác'
                                  : _selectedMode == FilterMode.month
                                      ? 'Chọn tháng khác'
                                      : 'Chọn năm khác',
                          style: const TextStyle(
                            color: AppColors.candidatePrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () {
                if (_selectedMode == FilterMode.custom) {
                  widget.ctrl.applyCustomRange(_customStart, _customEnd);
                } else {
                  final statsPeriod = _selectedMode == FilterMode.day
                      ? StatsPeriod.day
                      : _selectedMode == FilterMode.week
                          ? StatsPeriod.week
                          : _selectedMode == FilterMode.month
                              ? StatsPeriod.month
                              : StatsPeriod.year;
                  widget.ctrl.applyFilter(statsPeriod, _selectedDate);
                }
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.candidatePrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Áp dụng bộ lọc',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekRange {
  final DateTime start;
  final DateTime end;
  final String label;

  _WeekRange(this.start, this.end, this.label);
}

List<_WeekRange> _getWeeksOfMonth(int year, int month) {
  List<_WeekRange> weeks = [];
  DateTime firstDay = DateTime(year, month, 1);
  DateTime lastDay = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

  // Find the first Monday on or before firstDay
  DateTime current = firstDay.subtract(Duration(days: firstDay.weekday - 1));

  int weekNum = 1;
  while (current.isBefore(lastDay)) {
    DateTime weekEnd = current.add(const Duration(days: 6));
    weeks.add(_WeekRange(
      DateTime(current.year, current.month, current.day),
      DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59),
      'Tuần $weekNum (${DateFormat('dd/MM').format(current)} - ${DateFormat('dd/MM').format(weekEnd)})',
    ));
    current = current.add(const Duration(days: 7));
    weekNum++;
  }
  return weeks;
}
