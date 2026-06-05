import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../common/styles/app_colors.dart';
import '../../controller/login_controller.dart';
import '../../data/services/candidate_earnings_service.dart';

class CandidateEarningsScreen extends StatefulWidget {
  const CandidateEarningsScreen({super.key});

  @override
  State<CandidateEarningsScreen> createState() => _CandidateEarningsScreenState();
}

class _CandidateEarningsScreenState extends State<CandidateEarningsScreen> {
  final _earningsSvc = CandidateEarningsService();
  final _auth = Get.find<AuthController>();
  
  double _total = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTotal();
  }

  Future<void> _loadTotal() async {
    final uid = _auth.currentUser?.id;
    if (uid == null) return;
    try {
      final t = await _earningsSvc.getTotalEarnings(uid);
      if (mounted) setState(() { _total = t; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ví thu nhập'),
        backgroundColor: AppColors.candidatePrimary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.candidatePrimary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const Text('Tổng thu nhập', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        '${_total.toStringAsFixed(0)} ₫',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                      ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Lịch sử nhận lương', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          
          Expanded(
            child: StreamBuilder<List<EarningRecord>>(
              stream: _earningsSvc.streamEarnings(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const Center(child: Text('Chưa có dữ liệu thu nhập.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final r = list[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: const Icon(Icons.arrow_downward, color: Colors.green),
                        ),
                        title: Text(r.details, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(r.createdAt)),
                        trailing: Text(
                          '+${r.amount.toStringAsFixed(0)}₫',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
