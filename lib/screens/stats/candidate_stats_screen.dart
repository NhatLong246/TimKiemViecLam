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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PeriodTabs(ctrl: _dashCtrl),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _DateRangeRow(ctrl: _dashCtrl),
                ),
                const SizedBox(height: 12),
                _InsightCard(ctrl: _dashCtrl),
                _buildMainStats(summary),
                _buildSubStats(summary),
                const SizedBox(height: 16),
                _buildChartSection(),
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

  Widget _buildMainStats(CandidateEarningsSummary summary) {
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
            if (summary.totalPaidVnd != summary.periodPaidVnd) ...[
              const SizedBox(height: 8),
              Text(
                'Tổng đã giải ngân: ${summary.formatVnd(summary.totalPaidVnd)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            if (summary.pendingVnd > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Chờ giải ngân: ${summary.formatVnd(summary.pendingVnd)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            if (summary.walletBalanceVnd > 0) ...[
              const SizedBox(height: 8),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Ca đã GN',
              value: summary.jobCount.toDouble(),
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
              format: (v) => v > 0 ? '${v.toStringAsFixed(1)} ⭐' : '—',
              icon: Icons.star_outline,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required double value,
    required String Function(double) format,
    required IconData icon,
    required Color color,
  }) {
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
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Biểu đồ thu nhập & Giờ làm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cột: Giờ làm  •  Đường: Thu nhập (VNĐ)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: Obx(() {
                final data = _dashCtrl.chartData;
                if (data.isEmpty) {
                  return const Center(child: Text('Không có dữ liệu', style: TextStyle(color: Colors.grey)));
                }

                double maxPaid = 0;
                double maxHours = 0;
                for (final p in data) {
                  if (p.paidVnd > maxPaid) maxPaid = p.paidVnd;
                  if (p.hoursWorked > maxHours) maxHours = p.hoursWorked;
                }
                if (maxPaid == 0) maxPaid = 100000;
                if (maxHours == 0) maxHours = 10;

                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxHours * 1.2,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                data[idx].label,
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: data.asMap().entries.map((e) {
                      final idx = e.key;
                      final p = e.value;
                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: p.hoursWorked,
                            color: Colors.orange.withOpacity(0.6),
                            width: 12,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              }),
            ),
            // Layer Line Chart on top
            Transform.translate(
              offset: const Offset(0, -220),
              child: SizedBox(
                height: 220,
                child: Obx(() {
                  final data = _dashCtrl.chartData;
                  if (data.isEmpty) return const SizedBox.shrink();

                  double maxPaid = 0;
                  for (final p in data) {
                    if (p.paidVnd > maxPaid) maxPaid = p.paidVnd;
                  }
                  if (maxPaid == 0) maxPaid = 100000;

                  return LineChart(
                    LineChartData(
                      maxY: maxPaid * 1.2,
                      minY: 0,
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: data.asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(), e.value.paidVnd);
                          }).toList(),
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.green.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
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

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.ctrl});
  final CandidateDashboardController ctrl;

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
                  onTap: () => ctrl.updatePeriod(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.candidatePrimary : Colors.transparent,
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

class _DateRangeRow extends StatelessWidget {
  const _DateRangeRow({required this.ctrl});
  final CandidateDashboardController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() => Row(
          children: [
            _DateButton(
              label: 'Từ ngày',
              date: ctrl.startDate.value,
              onTap: () => ctrl.pickDateRange(context),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 16, color: AppColors.grey),
            ),
            _DateButton(
              label: 'Đến ngày',
              date: ctrl.endDate.value,
              onTap: () => ctrl.pickDateRange(context),
            ),
            const Spacer(),
            GestureDetector(
              onTap: ctrl.loadBenefits,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.candidatePrimary,
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
          border: Border.all(color: AppColors.candidatePrimary.withOpacity(0.3)),
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
                color: AppColors.candidatePrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
