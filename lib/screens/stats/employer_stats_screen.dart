import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/employer_stats_controller.dart';
import '../../data/models/employer_stats_model.dart';

class EmployerStatsScreen extends StatelessWidget {
  const EmployerStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(EmployerStatsController());
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Obx(() => CustomScrollView(
            slivers: [
              _buildSliverHeader(ctrl),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _PeriodTabs(ctrl: ctrl),
                      const SizedBox(height: 8),
                      _DateRangeRow(ctrl: ctrl),
                      const SizedBox(height: 12),
                      if (ctrl.isLoading.value)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: CircularProgressIndicator(
                              color: AppColors.employerPrimary,
                            ),
                          ),
                        )
                      else ...[
                        _SummaryGrid(ctrl: ctrl),
                        const SizedBox(height: 20),
                        _ChartCard(
                          title: 'Biểu đồ chi tiêu & Tuyển dụng',
                          subtitle: 'Cột: số người thuê  •  Đường: chi tiêu',
                          child: _SpendingHiringChart(ctrl: ctrl),
                        ),
                        const SizedBox(height: 16),
                        _ChartCard(
                          title: 'Biểu đồ nạp tiền',
                          subtitle: 'Tổng tiền nạp vào ví theo kỳ',
                          child: _DepositAreaChart(ctrl: ctrl),
                        ),
                        const SizedBox(height: 16),
                        _ChartCard(
                          title: 'Bài đăng tuyển dụng',
                          subtitle: 'Số lượng bài đăng theo kỳ',
                          child: _PostsBarChart(ctrl: ctrl),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          )),
    );
  }

  // ── Sliver header gradient ───────────────────────────────────────────
  SliverAppBar _buildSliverHeader(EmployerStatsController ctrl) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.employerPrimary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.employerGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Thống kê hoạt động',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Obx(() => Text(
                        '${DateFormat('dd/MM/yyyy').format(ctrl.startDate.value)}'
                        ' – ${DateFormat('dd/MM/yyyy').format(ctrl.endDate.value)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      )),
                ],
              ),
            ),
          ),
        ),
        title: null,
        titlePadding: EdgeInsets.zero,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Period Tabs
// ═══════════════════════════════════════════════════════════════════════════
class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Obx(() => Row(
            children: StatsPeriod.values.map((p) {
              final selected = ctrl.period.value == p;
              return Expanded(
                child: GestureDetector(
                  onTap: () => ctrl.setPeriod(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: selected ? AppColors.employerGradient : null,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.grey,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          )),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Date Range Row
// ═══════════════════════════════════════════════════════════════════════════
class _DateRangeRow extends StatelessWidget {
  const _DateRangeRow({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() => Row(
          children: [
            _DateButton(
              label: 'Từ ngày',
              date: ctrl.startDate.value,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: ctrl.startDate.value,
                  firstDate: DateTime(2020),
                  lastDate: ctrl.endDate.value,
                  builder: _datePickerTheme,
                );
                if (picked != null) {
                  ctrl.setDateRange(picked, ctrl.endDate.value);
                }
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 16, color: AppColors.grey),
            ),
            _DateButton(
              label: 'Đến ngày',
              date: ctrl.endDate.value,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: ctrl.endDate.value,
                  firstDate: ctrl.startDate.value,
                  lastDate: DateTime.now(),
                  builder: _datePickerTheme,
                );
                if (picked != null) {
                  ctrl.setDateRange(ctrl.startDate.value, picked);
                }
              },
            ),
            const Spacer(),
            GestureDetector(
              onTap: ctrl.loadData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.employerGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Lọc',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ));
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.employerPrimary,
          onPrimary: Colors.white,
        ),
      ),
      child: child!,
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.employerPrimary.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.employerPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Summary Grid 2x3
// ═══════════════════════════════════════════════════════════════════════════
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  Widget build(BuildContext context) {
    final s = ctrl.summary.value;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF4CAF50),
                iconBg: const Color(0xFFE8F5E9),
                label: 'Bài đăng đã duyệt',
                value: '${s.approvedPosts}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.access_time_filled,
                iconColor: const Color(0xFFF44336),
                iconBg: const Color(0xFFFFEBEE),
                label: 'Bài đăng quá hạn',
                value: '${s.cancelledPosts}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.group_outlined,
                iconColor: AppColors.employerPrimary,
                iconBg: const Color(0xFFF3E5F5),
                label: 'Số người đã thuê',
                value: '${s.totalHired}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.wallet_outlined,
                iconColor: AppColors.employerSecondary,
                iconBg: const Color(0xFFE3F2FD),
                label: 'Tổng tiền đã chi',
                value: ctrl.formatVnd(s.totalSpent),
                valueSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.add_card_outlined,
                iconColor: const Color(0xFF009688),
                iconBg: const Color(0xFFE0F2F1),
                label: 'Tổng tiền đã nạp',
                value: ctrl.formatVnd(s.totalDeposited),
                valueSize: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up,
                iconColor: const Color(0xFFFF9800),
                iconBg: const Color(0xFFFFF3E0),
                label: 'Hiệu suất chi',
                value: s.totalDeposited > 0
                    ? '${(s.totalSpent / s.totalDeposited * 100).toStringAsFixed(0)}%'
                    : '—',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.valueSize = 22,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.grey,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Chart Card wrapper
// ═══════════════════════════════════════════════════════════════════════════
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.grey),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Chart 1: Bar (hired) + Line (spent) overlay
// ═══════════════════════════════════════════════════════════════════════════
class _SpendingHiringChart extends StatelessWidget {
  const _SpendingHiringChart({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  Widget build(BuildContext context) {
    final data = ctrl.chartData;
    if (data.isEmpty) return _emptyChart();

    final maxHired = data.map((e) => e.hired.toDouble()).reduce((a, b) => a > b ? a : b);
    final maxSpent = data.map((e) => e.spent).reduce((a, b) => a > b ? a : b);
    final spentScale = maxHired > 0 && maxSpent > 0 ? maxHired / maxSpent : 1.0;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxHired * 1.3).clamp(5, double.infinity),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.dark.withOpacity(0.85),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final pt = data[groupIndex];
                if (rodIndex == 0) {
                  return BarTooltipItem(
                    '${pt.label}\nThuê: ${pt.hired} người\nChi: ${ctrl.formatVnd(pt.spent)}',
                    const TextStyle(color: Colors.white, fontSize: 11),
                  );
                }
                return null;
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _xInterval(data.length),
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[i].label,
                      style: const TextStyle(fontSize: 9, color: AppColors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style: const TextStyle(fontSize: 9, color: AppColors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.12),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(data.length, (i) {
            final pt = data[i];
            final spentBar = maxSpent > 0 ? pt.spent * spentScale : 0.0;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: pt.hired.toDouble(),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: spentBar,
                  color: AppColors.employerPrimary.withOpacity(0.2),
                  width: 6,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Chart 2: Area (deposited)
// ═══════════════════════════════════════════════════════════════════════════
class _DepositAreaChart extends StatelessWidget {
  const _DepositAreaChart({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  Widget build(BuildContext context) {
    final data = ctrl.chartData;
    if (data.isEmpty) return _emptyChart();

    final maxVal = data.map((e) => e.deposited).reduce((a, b) => a > b ? a : b);

    final spots = List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i].deposited),
    );

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          maxY: maxVal > 0 ? maxVal * 1.3 : 500000,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.dark.withOpacity(0.85),
              getTooltipItems: (spots) => spots.map((s) {
                final i = s.x.toInt();
                final pt = data[i];
                return LineTooltipItem(
                  '${pt.label}\n${ctrl.formatVnd(pt.deposited)}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _xInterval(data.length),
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[i].label,
                      style: const TextStyle(fontSize: 9, color: AppColors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (val, meta) => Text(
                  _shortNum(val),
                  style: const TextStyle(fontSize: 9, color: AppColors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.12),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [AppColors.employerPrimary, AppColors.employerSecondary],
              ),
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.employerPrimary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.employerPrimary.withOpacity(0.3),
                    AppColors.employerPrimary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Chart 3: Posts bar chart
// ═══════════════════════════════════════════════════════════════════════════
class _PostsBarChart extends StatelessWidget {
  const _PostsBarChart({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  Widget build(BuildContext context) {
    final data = ctrl.chartData;
    if (data.isEmpty) return _emptyChart();

    final maxVal = data.map((e) => e.posts.toDouble()).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxVal * 1.4).clamp(5, double.infinity),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.dark.withOpacity(0.85),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final pt = data[groupIndex];
                return BarTooltipItem(
                  '${pt.label}: ${pt.posts} bài',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _xInterval(data.length),
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[i].label,
                      style: const TextStyle(fontSize: 9, color: AppColors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style: const TextStyle(fontSize: 9, color: AppColors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.12),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(data.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].posts.toDouble(),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.employerPrimaryLight.withOpacity(0.7),
                      AppColors.employerPrimary,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════════════
Widget _emptyChart() => const SizedBox(
      height: 120,
      child: Center(
        child: Text(
          'Không có dữ liệu trong khoảng thời gian này',
          style: TextStyle(color: AppColors.grey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );

double _xInterval(int count) {
  if (count <= 7) return 1;
  if (count <= 14) return 2;
  if (count <= 31) return 5;
  return (count / 6).ceilToDouble();
}

String _shortNum(double val) {
  if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(0)}M';
  if (val >= 1000) return '${(val / 1000).toStringAsFixed(0)}K';
  return val.toStringAsFixed(0);
}
