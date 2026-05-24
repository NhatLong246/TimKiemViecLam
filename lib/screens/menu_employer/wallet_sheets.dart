import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:viecnow/data/models/wallet_summary_model.dart';
import 'package:viecnow/data/models/wallet_transaction_model.dart';
import 'package:viecnow/config/momo_config.dart';
import 'package:viecnow/data/services/wallet_service.dart';
import 'package:viecnow/data/services/wallet_withdraw_service.dart';

/// Bottom sheet / dialog dùng chung cho màn Tiền app.
class WalletSheets {
  static final _fmt = NumberFormat('#,###', 'vi_VN');
  static const _momoPink = Color(0xFFA50064);

  static void showWithdraw({
    required BuildContext context,
    required String userId,
    required WalletService wallet,
    required WalletSummaryModel summary,
    required VoidCallback onSuccess,
  }) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                const SizedBox(height: 16),
                const Text(
                  'Rút tiền về ví MoMo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Số dư app: ${_fmt.format(summary.walletBalance.toInt())}đ',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF757575),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hoàn tiền về ví MoMo Test (0917003000) — cùng tài khoản đã dùng khi nạp. '
                  'Số dư app chỉ trừ khi MoMo hoàn thành công.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
                const SizedBox(height: 14),
                _withdrawQuickAmounts(amountCtrl, summary.walletBalance),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Số tiền rút (VND)',
                    suffixText: 'đ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú (tùy chọn)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: submitting || !MomoConfig.isConfigured
                        ? null
                        : () async {
                            final raw = amountCtrl.text
                                .trim()
                                .replaceAll(RegExp(r'[,.\s]'), '');
                            final amount = int.tryParse(raw);
                            if (amount == null) {
                              Get.snackbar('Lỗi', 'Nhập số tiền hợp lệ');
                              return;
                            }
                            setSheet(() => submitting = true);
                            try {
                              final result =
                                  await wallet.withdraw.withdrawToMomo(
                                userId: userId,
                                amount: amount,
                                note: noteCtrl.text.trim(),
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              onSuccess();
                              Get.snackbar(
                                'Rút tiền thành công',
                                'MoMo đã hoàn ${_fmt.format(result.amount)}đ '
                                'về ví test. Mở app MoMo Test để kiểm tra.',
                                backgroundColor: Colors.green.shade100,
                                duration: const Duration(seconds: 5),
                              );
                            } catch (e) {
                              Get.snackbar(
                                'Không rút được',
                                e.toString().replaceFirst('Exception: ', ''),
                                backgroundColor: Colors.orange.shade100,
                                duration: const Duration(seconds: 6),
                              );
                            } finally {
                              setSheet(() => submitting = false);
                            }
                          },
                    icon: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                    label: Text(
                      submitting ? 'Đang gọi MoMo...' : 'Rút về MoMo',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _momoPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _withdrawQuickAmounts(
    TextEditingController amountCtrl,
    double balance,
  ) {
    final maxAmt = balance.floor();
    if (maxAmt < WalletWithdrawService.minAmount) {
      return const Text(
        'Số dư chưa đủ (tối thiểu 50.000đ)',
        style: TextStyle(color: Color(0xFFC62828), fontSize: 12),
      );
    }
    final presets = <int>{50000, 100000, 200000, maxAmt}
        .where((a) => a >= WalletWithdrawService.minAmount && a <= maxAmt)
        .toList()
      ..sort();
    return Row(
      children: presets.take(4).map((a) {
        final label = a == maxAmt ? 'Tối đa' : '${_fmt.format(a)}đ';
        return Expanded(
          child: GestureDetector(
            onTap: () => amountCtrl.text = a.toString(),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _momoPink,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static void showSpendingLimit({
    required BuildContext context,
    required String userId,
    required WalletService wallet,
    double? currentLimit,
    required VoidCallback onSaved,
  }) {
    final ctrl = TextEditingController(
      text: currentLimit != null && currentLimit > 0
          ? currentLimit.toInt().toString()
          : '',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              const SizedBox(height: 16),
              const Text(
                'Hạn mức chi tiêu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Giới hạn tối đa mỗi lần chi từ ví (đăng tin, thanh toán…). '
                'Để trống = không giới hạn.',
                style: TextStyle(fontSize: 13, color: Color(0xFF757575)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Hạn mức (VND)',
                  suffixText: 'đ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          await wallet.setSpendingLimit(userId, null);
                          if (ctx.mounted) Navigator.pop(ctx);
                          onSaved();
                          Get.snackbar(
                            'Đã lưu',
                            'Đã bỏ hạn mức chi tiêu',
                            backgroundColor: Colors.green.shade100,
                          );
                        } catch (e) {
                          Get.snackbar('Lỗi', '$e');
                        }
                      },
                      child: const Text('Không giới hạn'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final raw = ctrl.text
                            .trim()
                            .replaceAll(RegExp(r'[,.\s]'), '');
                        final v = double.tryParse(raw);
                        if (v == null || v < 10000) {
                          Get.snackbar(
                            'Lỗi',
                            'Nhập hạn mức tối thiểu 10.000đ',
                          );
                          return;
                        }
                        try {
                          await wallet.setSpendingLimit(userId, v);
                          if (ctx.mounted) Navigator.pop(ctx);
                          onSaved();
                          Get.snackbar(
                            'Đã lưu',
                            'Hạn mức: ${_fmt.format(v.toInt())}đ/lần chi',
                            backgroundColor: Colors.green.shade100,
                          );
                        } catch (e) {
                          Get.snackbar('Lỗi', '$e');
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFAD1457),
                      ),
                      child: const Text('Lưu'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showTerms(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: const [
              SizedBox(height: 8),
              Text(
                'Điều kiện sử dụng ví',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 14),
              Text(
                '1. Ví ViecNow dùng để nạp tiền và chi trả các dịch vụ trên app '
                '(đăng tin tuyển dụng, thanh toán lương theo chính sách nền tảng).\n\n'
                '2. Nạp tiền qua cổng MoMo (môi trường test): số tiền được cộng sau khi '
                'hệ thống xác nhận thanh toán thành công.\n\n'
                '3. Số dư khả dụng = tổng nạp − tổng chi (chỉ tính giao dịch hoàn tất).\n\n'
                '4. Hạn mức chi tiêu (nếu đặt) áp dụng cho mỗi lần trừ tiền từ ví, '
                'không áp dụng khi nạp tiền.\n\n'
                '5. Giao dịch pending quá 24 giờ có thể bị hủy; bạn có thể hủy thủ công '
                'trong lịch sử.\n\n'
                '6. Khiếu nại giao dịch: liên hệ hỗ trợ qua mục Khiếu nại trong app, '
                'kèm mã đơn MoMo (orderId) nếu có.\n\n'
                '7. Rút tiền: hoàn (refund) giao dịch nạp MoMo — tiền về ví MoMo đã thanh toán lúc nạp.\n\n'
                '8. MoMo sandbox chỉ dùng cho thử nghiệm — không phải tiền thật.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> exportStatement({
    required BuildContext context,
    required String userId,
    required WalletService wallet,
    required WalletSummaryModel summary,
    required List<WalletTransactionModel> transactions,
    String? companyName,
  }) async {
    final text = wallet.buildStatementText(
      userId: userId,
      summary: summary,
      transactions: transactions,
      companyName: companyName,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sao kê đã sao chép'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  static void showPendingActions({
    required BuildContext context,
    required WalletTransactionModel tx,
    required VoidCallback onResume,
    required Future<void> Function() onCancel,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tx.description,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_fmt.format(tx.amount.toInt())}đ • Chờ thanh toán MoMo',
              style: const TextStyle(color: Color(0xFFF57F17)),
            ),
            const SizedBox(height: 20),
            if (tx.payUrl != null && tx.payUrl!.isNotEmpty)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  onResume();
                },
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Tiếp tục thanh toán MoMo'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFA50064),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await onCancel();
              },
              child: const Text('Hủy giao dịch'),
            ),
          ],
        ),
      ),
    );
  }
}
