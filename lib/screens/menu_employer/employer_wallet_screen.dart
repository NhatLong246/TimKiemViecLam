import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

  static const _gradient = [Color(0xFFAD1457), Color(0xFF880E4F)];
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

  double _safeField(Map<String, dynamic>? d, String key) =>
      (d?[key] as num?)?.toDouble() ?? 0.0;

  Future<void> _doTopUp() async {
    final raw = _amountCtrl.text.trim().replaceAll(RegExp(r'[,.]'), '');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      Get.snackbar(
        'L\u1ed7i',
        'Vui l\u00f2ng nh\u1eadp s\u1ed1 ti\u1ec1n h\u1ee3p l\u1ec7',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final note = _noteCtrl.text.trim();
      final batch = FirebaseFirestore.instance.batch();

      final txRef =
          FirebaseFirestore.instance.collection('walletTransactions').doc();
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(_uid);

      batch.set(txRef, {
        'userId': _uid,
        'type': 'deposit',
        'amount': amount,
        'description': note.isEmpty ? 'N\u1ea1p ti\u1ec1n th\u1ee7 c\u00f4ng' : note,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        userRef,
        {
          'walletBalance': FieldValue.increment(amount),
          'totalDeposited': FieldValue.increment(amount),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      _amountCtrl.clear();
      _noteCtrl.clear();
      Get.back();
      Get.snackbar(
        'Th\u00e0nh c\u00f4ng',
        '\u0110\u00e3 n\u1ea1p ${_fmt.format(amount.toInt())}\u0111 v\u00e0o t\u00e0i kho\u1ea3n',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('L\u1ed7i', 'Kh\u00f4ng th\u1ec3 n\u1ea1p ti\u1ec1n: $e',
          backgroundColor: Colors.red.shade100);
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
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(            color: Theme.of(context).cardColor,
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'N\u1ea1p ti\u1ec1n v\u00e0o t\u00e0i kho\u1ea3n',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              const Text(
                'Ch\u1ecdn s\u1ed1 ti\u1ec1n ho\u1eb7c nh\u1eadp th\u1ee7 c\u00f4ng',
                style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 18),
              _buildQuickAmounts(),
              const SizedBox(height: 14),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'S\u1ed1 ti\u1ec1n (VND)',
                  prefixIcon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFFAD1457)),
                  suffixText: '\u0111',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFFAD1457), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Ghi ch\u00fa (t\u00f9y ch\u1ecdn)',
                  prefixIcon: const Icon(Icons.note_outlined,
                      color: Color(0xFF9E9E9E)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFAD1457)),
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
                            _doTopUp();
                          },
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.add_rounded,
                            color: Colors.white),
                    label: Text(
                      _submitting
                          ? '\u0110ang x\u1eed l\u00fd...'
                          : 'X\u00e1c nh\u1eadn n\u1ea1p ti\u1ec1n',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFAD1457),
                      disabledBackgroundColor:
                          const Color(0xFFAD1457).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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
                    color: Color(0xFFAD1457)),
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .snapshots(),
        builder: (ctx, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          final balance = _safeField(data, 'walletBalance');
          final totalSpent = _safeField(data, 'totalSpent');
          final totalDeposited = _safeField(data, 'totalDeposited');
          return CustomScrollView(
            slivers: [
              _buildHeader(balance, totalDeposited, totalSpent),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildActionGrid()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildTabBar()),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _WalletHistoryTab(uid: _uid),
                      _WalletStatsTab(uid: _uid),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _buildHeader(
      double balance, double totalDeposited, double totalSpent) {
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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const Text(
                      'Ti\u1ec1n app',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
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
                      style:
                          TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_fmt.format(balance.toInt())}\u0111',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _statPill(Icons.add_circle_outline_rounded,
                            'T\u1ed5ng n\u1ea1p', totalDeposited),
                        const SizedBox(width: 14),
                        _statPill(Icons.trending_down_rounded,
                            '\u0110\u00e3 chi', totalSpent),
                      ],
                    ),
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
      child: Row(children: [
        Icon(icon, color: Colors.white70, size: 15),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 11)),
          Text(
            '${_fmt.format(value.toInt())}\u0111',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700),
          ),
        ]),
      ]),
    );
  }

  Widget _buildActionGrid() {
    final items = [
      _WalletAction('N\u1ea1p ti\u1ec1n', Icons.add_rounded,
          const Color(0xFF2E7D32), _showTopUpSheet),
      _WalletAction('\u0110\u1eb7t h\u1ea1n m\u1ee9c', Icons.tune_rounded,
          const Color(0xFF1565C0), () {}),
      _WalletAction('\u0110i\u1ec1u ki\u1ec7n', Icons.info_outline_rounded,
          const Color(0xFFF57F17), () {}),
      _WalletAction('Xu\u1ea5t sao k\u00ea', Icons.download_rounded,
          const Color(0xFFAD1457), () {}),
    ];
    return Row(
      children: items.map((a) {
        return Expanded(
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
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: a.color.withOpacity(0.12),
                      shape: BoxShape.circle),
                  child: Icon(a.icon, color: a.color, size: 20),
                ),
                const SizedBox(height: 6),
                Text(a.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF424242))),
              ]),
            ),
          ),
        );
      }).toList(),
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
              offset: const Offset(0, 2))
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFFAD1457),
        unselectedLabelColor: const Color(0xFF9E9E9E),
        indicatorColor: const Color(0xFFAD1457),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700),
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
  const _WalletHistoryTab({required this.uid});

  static final _fmt = NumberFormat('#,###', 'vi_VN');

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(
          child: Text('Ch\u01b0a \u0111\u0103ng nh\u1eadp'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('walletTransactions')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
              child: Text('L\u1ed7i: ${snap.error}',
                  style: const TextStyle(color: Color(0xFF9E9E9E))));
        }
        final docs = List.of(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final ta = (a.data() as Map)['createdAt'] as Timestamp?;
          final tb = (b.data() as Map)['createdAt'] as Timestamp?;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.receipt_long_outlined,
                    size: 56, color: Color(0xFFBDBDBD)),
                SizedBox(height: 12),
                Text(
                  'Ch\u01b0a c\u00f3 giao d\u1ecbch n\u00e0o',
                  style: TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 15),
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
                  offset: const Offset(0, 3))
            ],
          ),
          child: ListView.separated(
            itemCount: docs.length,
            shrinkWrap: false,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 74),
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final isCredit = d['type'] == 'deposit' ||
                  d['type'] == 'refund';
              final amount =
                  (d['amount'] as num?)?.toDouble() ?? 0;
              final ts = d['createdAt'] as Timestamp?;
              final date = ts != null
                  ? DateFormat('dd/MM/yyyy HH:mm')
                      .format(ts.toDate())
                  : '\u0110ang x\u1eed l\u00fd...';
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCredit
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCredit
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: isCredit
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['description'] as String? ??
                                (d['type'] as String? ?? ''),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF212121)),
                          ),
                          const SizedBox(height: 2),
                          Text(date,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF9E9E9E))),
                        ]),
                  ),
                  Text(
                    '${isCredit ? '+' : '-'}${_fmt.format(amount.toInt())}\u0111',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isCredit
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                    ),
                  ),
                ]),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────
class _WalletStatsTab extends StatelessWidget {
  final String uid;
  const _WalletStatsTab({required this.uid});

  static final _fmt = NumberFormat('#,###', 'vi_VN');

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('walletTransactions')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
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
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final ts = d['createdAt'] as Timestamp?;
          if (ts == null) continue;
          final key = DateFormat('MM/yyyy').format(ts.toDate());
          final amount = (d['amount'] as num?)?.toDouble() ?? 0;
          final isCredit =
              d['type'] == 'deposit' || d['type'] == 'refund';
          if (deposited.containsKey(key)) {
            if (isCredit) {
              deposited[key] = (deposited[key] ?? 0) + amount;
            } else {
              spent[key] = (spent[key] ?? 0) + amount;
            }
          }
        }

        final labels = months
            .map((m) => DateFormat('T.MM').format(m))
            .toList();
        final maxVal = [
          ...deposited.values,
          ...spent.values,
          1.0,
        ].reduce((a, b) => a > b ? a : b);

        final totalDep =
            deposited.values.fold(0.0, (a, b) => a + b);
        final totalSpent =
            spent.values.fold(0.0, (a, b) => a + b);

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
                        offset: const Offset(0, 3))
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
                          color: Color(0xFF212121)),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      _dot(const Color(0xFF2E7D32), 'N\u1ea1p'),
                      const SizedBox(width: 14),
                      _dot(const Color(0xFFC62828), 'Chi'),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150,
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: List.generate(months.length,
                            (i) {
                          final key = DateFormat('MM/yyyy')
                              .format(months[i]);
                          final dep = deposited[key] ?? 0;
                          final spn = spent[key] ?? 0;
                          final depH = maxVal > 0
                              ? (dep / maxVal) * 120
                              : 0.0;
                          final spnH = maxVal > 0
                              ? (spn / maxVal) * 120
                              : 0.0;
                          return Expanded(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    _bar(depH,
                                        const Color(0xFF2E7D32)),
                                    const SizedBox(width: 3),
                                    _bar(spnH,
                                        const Color(0xFFC62828)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(labels[i],
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color:
                                            Color(0xFF9E9E9E))),
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
                  ctx,
                  'T\u1ed5ng \u0111\u00e3 n\u1ea1p',
                  totalDep,
                  const Color(0xFF2E7D32),
                  Icons.add_circle_outline_rounded),
              const SizedBox(height: 10),
              _summaryCard(
                  ctx,
                  'T\u1ed5ng \u0111\u00e3 chi',
                  totalSpent,
                  const Color(0xFFC62828),
                  Icons.remove_circle_outline_rounded),
            ],
          ),
        );
      },
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

  Widget _dot(Color color, String label) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF616161))),
      ]);

  Widget _summaryCard(BuildContext context, String label, double value,
      Color color, IconData icon) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121))),
        ),
        Text(
          '${_fmt.format(value.toInt())}\u0111',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color),
        ),
      ]),
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
