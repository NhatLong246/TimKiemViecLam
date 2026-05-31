import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/candidate_dashboard_controller.dart';
import '../../controller/login_controller.dart';
import '../../data/models/candidate_dashboard_models.dart';
import '../menu_candidate/candidate_benefits_screen.dart';

class CandidateStatsScreen extends StatefulWidget {
  const CandidateStatsScreen({super.key});

  @override
  State<CandidateStatsScreen> createState() => _CandidateStatsScreenState();
}

class _CandidateStatsScreenState extends State<CandidateStatsScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final CandidateDashboardController _dashCtrl =
      Get.put(CandidateDashboardController());

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
          return Center(
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
                _buildMainStats(summary),
                _buildSubStats(summary),
                _buildHistorySection(_dashCtrl.payments),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPeriodNote(bool isDark) {
    final now = DateTime.now();
    final monthLabel = 'Tháng ${now.month}, ${now.year}';
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Thu nhập tháng này: $monthLabel · Giờ làm tính từ điểm danh thực tế',
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
              color: AppColors.candidatePrimary.withValues(alpha: 0.3),
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
                  'Thu nhập tháng này của $displayName',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              summary.formatVnd(summary.monthPaidVnd),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (summary.totalPaidVnd != summary.monthPaidVnd) ...[
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
    final ratingText = summary.avgRating > 0
        ? '${summary.avgRating.toStringAsFixed(1)} ⭐'
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Ca đã GN',
              value: '${summary.jobCount}',
              icon: Icons.work_outline,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Giờ làm',
              value: '${summary.hoursWorked}h',
              icon: Icons.timer_outlined,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Đánh giá',
              value: ratingText,
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
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
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
                          color: AppColors.candidatePrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
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
