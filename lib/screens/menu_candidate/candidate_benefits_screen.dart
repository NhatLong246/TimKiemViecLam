import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/candidate_dashboard_controller.dart';
import '../../data/models/candidate_dashboard_models.dart';
import '../../routes/app_routes.dart';
import 'candidate_menu_scaffold.dart';

class CandidateBenefitsScreen extends StatefulWidget {
  const CandidateBenefitsScreen({super.key});

  @override
  State<CandidateBenefitsScreen> createState() => _CandidateBenefitsScreenState();
}

class _CandidateBenefitsScreenState extends State<CandidateBenefitsScreen> {
  final _ctrl = Get.put(CandidateDashboardController());
  final _withdrawAmountCtrl = TextEditingController();
  final _withdrawNoteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.loadBenefits();
  }

  @override
  void dispose() {
    _withdrawAmountCtrl.dispose();
    _withdrawNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CandidateMenuScaffold(
      title: 'Thu nhập & quyền lợi',
      body: Obx(() {
        if (_ctrl.isLoading.value && _ctrl.payments.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: candidateMenuPrimary),
          );
        }
        final summary = _ctrl.summary.value;
        return RefreshIndicator(
          color: candidateMenuPrimary,
          onRefresh: _ctrl.loadBenefits,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (summary != null) _buildWalletCard(summary),
              const SizedBox(height: 20),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              const Text(
                'Lịch sử thanh toán',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              if (_ctrl.payments.isEmpty)
                _emptyPayments()
              else
                ..._ctrl.payments.map(_paymentTile),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildWalletCard(CandidateEarningsSummary s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: candidateMenuPrimary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Đã nhận (tháng này)',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              InkWell(
                onTap: () => _showWithdrawSheet(s),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                        size: 15,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Tiền về tài khoản',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.formatVnd(s.monthPaidVnd),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (s.totalPaidVnd != s.monthPaidVnd) ...[
            const SizedBox(height: 6),
            Text(
              'Tổng đã nhận: ${s.formatVnd(s.totalPaidVnd)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _walletChip(
                  'Chờ nhận',
                  s.formatVnd(s.pendingVnd),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _walletChip(
                  'Số dư ví',
                  s.formatVnd(s.walletBalanceVnd),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWithdrawSheet(CandidateEarningsSummary summary) {
    final available = summary.walletBalanceVnd;
    _withdrawAmountCtrl.clear();
    _withdrawNoteCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rút tiền về tài khoản',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Số dư khả dụng: ${summary.formatVnd(available)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _withdrawAmountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tiền muốn rút',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _withdrawNoteCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tuỳ chọn)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: Obx(
                () => ElevatedButton(
                  onPressed: _ctrl.isWithdrawing.value
                      ? null
                      : () async {
                          final raw = _withdrawAmountCtrl.text
                              .trim()
                              .replaceAll(RegExp(r'[^0-9]'), '');
                          final amount = int.tryParse(raw) ?? 0;
                          if (amount <= 0) {
                            Get.snackbar('Lỗi', 'Nhập số tiền hợp lệ');
                            return;
                          }
                          if (amount > available) {
                            Get.snackbar('Lỗi', 'Số tiền rút vượt số dư khả dụng');
                            return;
                          }
                          try {
                            await _ctrl.withdraw(
                              amountVnd: amount,
                              note: _withdrawNoteCtrl.text.trim(),
                            );
                            if (mounted) Navigator.pop(ctx);
                            Get.snackbar(
                              'Thành công',
                              'Đã rút ${summary.formatVnd(amount)}',
                            );
                          } catch (e) {
                            Get.snackbar(
                              'Lỗi',
                              e.toString().replaceFirst('Exception: ', ''),
                            );
                          }
                        },
                  child: _ctrl.isWithdrawing.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Xác nhận rút tiền'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            icon: Icons.account_balance_outlined,
            label: 'Tài khoản\nngân hàng',
            color: const Color(0xFF1E88E5),
            onTap: () => Navigator.pushNamed(context, AppRoutes.myBankAccountview),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            icon: Icons.bar_chart_rounded,
            label: 'Báo cáo\nthu nhập',
            color: const Color(0xFF00897B),
            onTap: () => Navigator.pushNamed(context, AppRoutes.stats),
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentTile(CandidatePayment p) {
    final statusColor = p.status == 'paid'
        ? candidateMenuPrimary
        : p.status == 'disputed'
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.payments_outlined, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.jobTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.employerName,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                if (p.benefitNote != null && p.benefitNote!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    p.benefitNote!,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${p.amountDisplay}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: candidateMenuPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                p.statusLabel,
                style: TextStyle(fontSize: 11, color: statusColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyPayments() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        'Chưa có khoản thanh toán nào.',
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }
}
