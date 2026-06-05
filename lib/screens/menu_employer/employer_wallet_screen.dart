import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viecnow/config/momo_config.dart';
import 'package:viecnow/data/models/wallet_summary_model.dart';
import 'package:viecnow/data/models/wallet_transaction_model.dart';
import 'package:viecnow/data/services/wallet_service.dart';
import 'package:viecnow/screens/menu_employer/momo_checkout_screen.dart';
import 'package:viecnow/screens/menu_employer/wallet_sheets.dart';

class EmployerWalletScreen extends StatefulWidget {
  const EmployerWalletScreen({super.key});
  @override
  State<EmployerWalletScreen> createState() => _EmployerWalletScreenState();
}

class _EmployerWalletScreenState extends State<EmployerWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  final _wallet = WalletService();

  static const _gradient = [Color(0xFFAD1457), Color(0xFF880E4F)];
  static const _momoPink = Color(0xFFA50064);
  final _fmt = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  int? _parseAmountVnd() {
    final raw = _amountCtrl.text.trim().replaceAll(RegExp(r'[,.\s]'), '');
    final amount = int.tryParse(raw);
    if (amount == null || amount < 10000) return null;
    return amount;
  }

  Future<void> _doTopUpWithMomo() async {
    if (_uid.isEmpty) {
      Get.snackbar('Lỗi', 'Vui lòng đăng nhập');
      return;
    }
    if (!MomoConfig.isConfigured) {
      Get.snackbar('MoMo', 'Chưa cấu hình MoMo (${MomoConfig.githubSample})');
      return;
    }

    final amount = _parseAmountVnd();
    if (amount == null) {
      Get.snackbar(
        'Lỗi',
        'Nhập số tiền tối thiểu 10.000đ',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final note = _noteCtrl.text.trim();
      final momo = await _wallet.deposit.startMomoDeposit(
        userId: _uid,
        amount: amount,
        note: note,
      );

      if (!mounted) return;
      Get.back();

      bool? paid;
      if (kIsWeb) {
        final uri = Uri.parse(momo.payUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        paid = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Thanh toán MoMo'),
            content: const Text(
              'Sau khi thanh toán xong trên MoMo, bấm "Đã thanh toán" để cộng tiền vào ví.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                style: FilledButton.styleFrom(backgroundColor: _momoPink),
                child: const Text('Đã thanh toán'),
              ),
            ],
          ),
        );
        if (paid != true) {
          await _wallet.deposit.markDepositFailed(momo.orderId, _uid);
        }
      } else {
        paid = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => MomoCheckoutScreen(
              payUrl: momo.payUrl,
              deeplink: momo.deeplink,
              orderId: momo.orderId,
              requestId: momo.requestId,
              amount: amount,
              userId: _uid,
            ),
          ),
        );
      }

      _amountCtrl.clear();
      _noteCtrl.clear();

      if (paid == true && !kIsWeb) {
        Get.snackbar(
          'Thành công',
          'Đã nạp ${_fmt.format(amount)}đ qua MoMo',
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900,
          duration: const Duration(seconds: 3),
        );
      } else if (paid == true && kIsWeb) {
        try {
          await _wallet.deposit.confirmMomoDeposit(
            userId: _uid,
            orderId: momo.orderId,
            requestId: momo.requestId,
            amount: amount,
          );
          Get.snackbar(
            'Thành công',
            'Đã nạp ${_fmt.format(amount)}đ qua MoMo',
            backgroundColor: Colors.green.shade100,
            colorText: Colors.green.shade900,
            duration: const Duration(seconds: 3),
          );
        } catch (e) {
          Get.snackbar(
            'Chưa xác nhận',
            e.toString().replaceFirst('Exception: ', ''),
            backgroundColor: Colors.orange.shade100,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi MoMo',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showTopUpSheet() {
    _amountCtrl.clear();
    _noteCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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
                'Nạp tiền qua cổng MoMo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              const Text(
                'Chọn số tiền, thanh toán trên MoMo — tiền vào ví sau khi xác nhận',
                style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Hình thức thanh toán',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF616161),
                ),
              ),
              const SizedBox(height: 8),
              _buildMomoMethodCard(),
              const SizedBox(height: 14),
              _buildQuickAmounts(),
              const SizedBox(height: 14),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'S\u1ed1 ti\u1ec1n (VND)',
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFFAD1457),
                  ),
                  suffixText: '\u0111',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFAD1457),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Ghi ch\u00fa (t\u00f9y ch\u1ecdn)',
                  prefixIcon: const Icon(
                    Icons.note_outlined,
                    color: Color(0xFF9E9E9E),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFAD1457)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              StatefulBuilder(
                builder: (ctx, setS) => SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _submitting
                        ? null
                        : () {
                            setS(() {});
                            _doTopUpWithMomo();
                          },
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.qr_code_2_rounded,
                            color: Colors.white,
                          ),
                    label: Text(
                      _submitting
                          ? 'Đang chuyển MoMo...'
                          : 'Thanh toán bằng MoMo',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _momoPink,
                      disabledBackgroundColor: _momoPink.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMomoMethodCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _momoPink, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _momoPink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'MoMo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cổng thanh toán MoMo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _momoPink,
                  ),
                ),
                SizedBox(height: 4),
                const Text(
                  'GitHub momo-wallet/payment • MoMo Test 0917003000',
                  style: TextStyle(fontSize: 11, color: Color(0xFF757575)),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: _momoPink, size: 24),
        ],
      ),
    );
  }

  Widget _buildQuickAmounts() {
    const amounts = [50000.0, 100000.0, 200000.0, 500000.0];
    return Row(
      children: amounts.map((a) {
        return Expanded(
          child: GestureDetector(
            onTap: () => _amountCtrl.text = a.toInt().toString(),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE4EC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_fmt.format(a.toInt())}\u0111',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFAD1457),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTopUpSheet,
        backgroundColor: const Color(0xFFAD1457),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'N\u1ea1p ti\u1ec1n',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<WalletSummaryModel>(
        stream: _wallet.watchSummary(_uid),
        builder: (ctx, snap) {
          final summary = snap.data ?? const WalletSummaryModel();
          return StreamBuilder<List<WalletTransactionModel>>(
            stream: _wallet.watchTransactions(_uid),
            builder: (ctx2, txSnap) {
              final txs = txSnap.data ?? const [];
              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  _buildHeader(summary),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildActionGrid(summary, txs),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(child: _buildTabBar()),
                  ),
                ],
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _WalletHistoryTab(
                        uid: _uid,
                        wallet: _wallet,
                        onResumeMomo: _resumeMomoPayment,
                      ),
                      _WalletStatsTab(transactions: txs),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _resumeMomoPayment(WalletTransactionModel tx) async {
    if (tx.payUrl == null || tx.orderId == null || tx.requestId == null) {
      Get.snackbar('Lỗi', 'Thiếu thông tin thanh toán MoMo');
      return;
    }
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MomoCheckoutScreen(
          payUrl: tx.payUrl!,
          deeplink: null,
          orderId: tx.orderId!,
          requestId: tx.requestId!,
          amount: tx.amount.toInt(),
          userId: _uid,
        ),
      ),
    );
    if (paid == true) {
      Get.snackbar(
        'Thành công',
        'Đã nạp ${_fmt.format(tx.amount.toInt())}đ qua MoMo',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
    }
  }

  SliverToBoxAdapter _buildHeader(WalletSummaryModel summary) {
    final balance = summary.walletBalance;
    final heldBalance = summary.walletHeldBalance;
    final totalDeposited = summary.totalDeposited;
    final totalSpent = summary.totalSpent;
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradient,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Text(
                      'Ti\u1ec1n app',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                child: Column(
                  children: [
                    const Text(
                      'S\u1ed1 d\u01b0 kh\u1ea3 d\u1ee5ng',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_fmt.format(balance.toInt())}\u0111',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 10,
                      children: [
                        _statPill(
                          Icons.add_circle_outline_rounded,
                          'T\u1ed5ng n\u1ea1p',
                          totalDeposited,
                        ),
                        _statPill(
                          Icons.trending_down_rounded,
                          '\u0110\u00e3 chi',
                          totalSpent,
                        ),
                        if (heldBalance > 0) ...[
                          _statPill(
                            Icons.lock_clock_rounded,
                            'T\u1ea1m gi\u1eef',
                            heldBalance,
                          ),
                        ],
                      ],
                    ),
                    if (summary.hasSpendingLimit) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Hạn mức chi: ${_fmt.format(summary.walletSpendingLimit!.toInt())}\u0111/lần',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statPill(IconData icon, String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 15),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              Text(
                '${_fmt.format(value.toInt())}\u0111',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(
    WalletSummaryModel summary,
    List<WalletTransactionModel> txs,
  ) {
    Widget tile(_WalletAction a) => Expanded(
      child: GestureDetector(
        onTap: a.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: a.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(a.icon, color: a.color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                a.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            tile(
              _WalletAction(
                'Nạp tiền',
                Icons.add_rounded,
                const Color(0xFF2E7D32),
                _showTopUpSheet,
              ),
            ),
            tile(
              _WalletAction('Rút MoMo', Icons.send_rounded, _momoPink, () {
                WalletSheets.showWithdraw(
                  context: context,
                  userId: _uid,
                  wallet: _wallet,
                  summary: summary,
                  onSuccess: () => setState(() {}),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            tile(
              _WalletAction(
                'Hạn mức',
                Icons.tune_rounded,
                const Color(0xFF1565C0),
                () {
                  WalletSheets.showSpendingLimit(
                    context: context,
                    userId: _uid,
                    wallet: _wallet,
                    currentLimit: summary.walletSpendingLimit,
                    onSaved: () => setState(() {}),
                  );
                },
              ),
            ),
            tile(
              _WalletAction(
                'Điều kiện',
                Icons.info_outline_rounded,
                const Color(0xFFF57F17),
                () {
                  WalletSheets.showTerms(context);
                },
              ),
            ),
            tile(
              _WalletAction(
                'Sao kê',
                Icons.download_rounded,
                const Color(0xFFAD1457),
                () {
                  WalletSheets.exportStatement(
                    context: context,
                    userId: _uid,
                    wallet: _wallet,
                    summary: summary,
                    transactions: txs,
                    companyName: summary.companyName,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFFAD1457),
        unselectedLabelColor: const Color(0xFF9E9E9E),
        indicatorColor: const Color(0xFFAD1457),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'L\u1ecbch s\u1eed giao d\u1ecbch'),
          Tab(text: 'Th\u1ed1ng k\u00ea chi ti\u00eau'),
        ],
      ),
    );
  }
}

// ── History Tab ───────────────────────────────────────────────────────────────
class _WalletHistoryTab extends StatelessWidget {
  final String uid;
  final WalletService wallet;
  final void Function(WalletTransactionModel tx) onResumeMomo;

  const _WalletHistoryTab({
    required this.uid,
    required this.wallet,
    required this.onResumeMomo,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(child: Text('Chưa đăng nhập'));
    }
    return StreamBuilder<List<WalletTransactionModel>>(
      stream: wallet.watchTransactions(uid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Lỗi: ${snap.error}',
              style: const TextStyle(color: Color(0xFF9E9E9E)),
            ),
          );
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 56,
                  color: Color(0xFFBDBDBD),
                ),
                SizedBox(height: 12),
                Text(
                  'Chưa có giao dịch nào',
                  style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 15),
                ),
              ],
            ),
          );
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 74),
            itemBuilder: (_, i) {
              final t = list[i];
              return _HistoryTile(
                tx: t,
                onTap: t.isPending && t.paymentMethod == 'momo'
                    ? () => WalletSheets.showPendingActions(
                        context: context,
                        tx: t,
                        onResume: () => onResumeMomo(t),
                        onCancel: () async {
                          if (t.orderId != null) {
                            await wallet.deposit.markDepositFailed(
                              t.orderId!,
                              uid,
                            );
                          }
                          Get.snackbar('Đã hủy', 'Giao dịch đã được hủy');
                        },
                      )
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final WalletTransactionModel tx;
  final VoidCallback? onTap;

  const _HistoryTile({required this.tx, this.onTap});

  static final _fmt = NumberFormat('#,###', 'vi_VN');

  @override
  Widget build(BuildContext context) {
    final isPending = tx.isPending;
    final isFailed = tx.isFailed;
    final isCredit = tx.isCredit;
    final method = tx.paymentMethod;
    final date = tx.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt!)
        : 'Đang xử lý...';

    Color bg;
    Color iconColor;
    IconData icon;
    if (isPending) {
      bg = const Color(0xFFFFF3E0);
      iconColor = const Color(0xFFF57F17);
      icon = Icons.hourglass_top_rounded;
    } else if (isFailed) {
      bg = const Color(0xFFEEEEEE);
      iconColor = const Color(0xFF757575);
      icon = Icons.cancel_outlined;
    } else if (method == 'momo' && tx.type == 'withdrawal') {
      bg = const Color(0xFFFFF0F6);
      iconColor = const Color(0xFFA50064);
      icon = Icons.send_rounded;
    } else if (method == 'momo' && tx.type == 'deposit') {
      bg = const Color(0xFFFFF0F6);
      iconColor = const Color(0xFFA50064);
      icon = Icons.qr_code_2_rounded;
    } else if (isCredit) {
      bg = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF2E7D32);
      icon = Icons.arrow_downward_rounded;
    } else {
      bg = const Color(0xFFFFEBEE);
      iconColor = const Color(0xFFC62828);
      icon = Icons.arrow_upward_rounded;
    }

    String amountText;
    Color amountColor;
    if (isPending) {
      amountText = '${_fmt.format(tx.amount.toInt())}đ';
      amountColor = const Color(0xFFF57F17);
    } else if (isFailed) {
      amountText = '${_fmt.format(tx.amount.toInt())}đ';
      amountColor = const Color(0xFF757575);
    } else {
      amountText = '${isCredit ? '+' : '-'}${_fmt.format(tx.amount.toInt())}đ';
      amountColor = isCredit
          ? const Color(0xFF2E7D32)
          : const Color(0xFFC62828);
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description.isNotEmpty ? tx.description : tx.type,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 2),
                    Text(
                      tx.type == 'withdrawal'
                          ? 'Đang hoàn tiền MoMo...'
                          : method == 'momo'
                          ? 'Chờ MoMo • Chạm để tiếp tục'
                          : 'Đang xử lý',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFF57F17),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (isFailed && tx.type == 'withdrawal') ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Hoàn tiền thất bại',
                      style: TextStyle(fontSize: 11, color: Color(0xFF757575)),
                    ),
                  ] else if (isFailed) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Đã hủy / thất bại',
                      style: TextStyle(fontSize: 11, color: Color(0xFF757575)),
                    ),
                  ] else if (tx.type == 'withdrawal' && tx.isCompleted) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Đã hoàn về MoMo Test',
                      style: TextStyle(fontSize: 11, color: Color(0xFF757575)),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amountText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────
class _WalletStatsTab extends StatelessWidget {
  final List<WalletTransactionModel> transactions;
  const _WalletStatsTab({required this.transactions});

  static final _fmt = NumberFormat('#,###', 'vi_VN');

  @override
  Widget build(BuildContext context) {
    final completed = transactions.where((t) => t.isCompleted).toList();
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      return DateTime(now.year, now.month - (5 - i), 1);
    });

    final Map<String, double> deposited = {};
    final Map<String, double> spent = {};
    for (final m in months) {
      final key = DateFormat('MM/yyyy').format(m);
      deposited[key] = 0;
      spent[key] = 0;
    }
    for (final t in completed) {
      final d = t.createdAt;
      if (d == null) continue;
      final key = DateFormat('MM/yyyy').format(d);
      if (!deposited.containsKey(key)) continue;
      if (t.isCredit) {
        deposited[key] = (deposited[key] ?? 0) + t.amount;
      } else if (t.isDebit) {
        spent[key] = (spent[key] ?? 0) + t.amount;
      }
    }

    final labels = months.map((m) => DateFormat('T.MM').format(m)).toList();
    final maxVal = [
      ...deposited.values,
      ...spent.values,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    final totalDep = deposited.values.fold(0.0, (a, b) => a + b);
    final totalSpentChart = spent.values.fold(0.0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bi\u1ebfn \u0111\u1ed9ng 6 th\u00e1ng',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _dot(const Color(0xFF2E7D32), 'N\u1ea1p'),
                    const SizedBox(width: 14),
                    _dot(const Color(0xFFC62828), 'Chi'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(months.length, (i) {
                      final key = DateFormat('MM/yyyy').format(months[i]);
                      final dep = deposited[key] ?? 0;
                      final spn = spent[key] ?? 0;
                      final depH = maxVal > 0 ? (dep / maxVal) * 120 : 0.0;
                      final spnH = maxVal > 0 ? (spn / maxVal) * 120 : 0.0;
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _bar(depH, const Color(0xFF2E7D32)),
                                const SizedBox(width: 3),
                                _bar(spnH, const Color(0xFFC62828)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              labels[i],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9E9E9E),
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
          const SizedBox(height: 14),
          _summaryCard(
            context,
            'T\u1ed5ng \u0111\u00e3 n\u1ea1p',
            totalDep,
            const Color(0xFF2E7D32),
            Icons.add_circle_outline_rounded,
          ),
          const SizedBox(height: 10),
          _summaryCard(
            context,
            'Tổng đã chi (6 tháng)',
            totalSpentChart,
            const Color(0xFFC62828),
            Icons.remove_circle_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _bar(double h, Color color) => AnimatedContainer(
    duration: const Duration(milliseconds: 500),
    curve: Curves.easeOut,
    width: 14,
    height: h.clamp(2.0, 120.0),
    decoration: BoxDecoration(
      color: color.withOpacity(0.85),
      borderRadius: BorderRadius.circular(4),
    ),
  );

  Widget _dot(Color color, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
      ),
    ],
  );

  Widget _summaryCard(
    BuildContext context,
    String label,
    double value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF212121),
              ),
            ),
          ),
          Text(
            '${_fmt.format(value.toInt())}\u0111',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────
class _WalletAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _WalletAction(this.label, this.icon, this.color, this.onTap);
}
