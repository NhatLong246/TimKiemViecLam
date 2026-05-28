import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/models/disbursement_notice_model.dart';
import '../../data/services/job_workflow_service.dart';

class AdminDisbursementScreen extends StatefulWidget {
  const AdminDisbursementScreen({super.key});

  @override
  State<AdminDisbursementScreen> createState() => _AdminDisbursementScreenState();
}

class _AdminDisbursementScreenState extends State<AdminDisbursementScreen> {
  final _workflow = JobWorkflowService();
  List<DisbursementNoticeModel> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _pending = await _workflow.listPendingForAdmin();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(DisbursementNoticeModel n) async {
    try {
      await _workflow.approveDisbursementRequest(n.noticeId);
      Get.snackbar('Đã duyệt', 'NTD có thể giải ngân',
          backgroundColor: Colors.green, colorText: Colors.white);
      await _load();
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    }
  }

  Future<void> _reject(DisbursementNoticeModel n) async {
    try {
      await _workflow.rejectDisbursementRequest(n.noticeId);
      await _load();
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    }
  }

  Future<void> _closeGroup(DisbursementNoticeModel n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đóng nhóm?'),
        content: const Text(
          'Admin đóng nhóm và tin tuyển dụng. NTD không cần giải ngân qua app.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đóng nhóm'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _workflow.adminCloseGroup(
        noticeId: n.noticeId,
        groupId: n.groupId,
        jobId: n.jobId,
      );
      Get.snackbar('Đã đóng', 'Nhóm đã được đóng',
          backgroundColor: Colors.green, colorText: Colors.white);
      await _load();
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
        title: const Text('Duyệt giải ngân'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _pending.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 64),
                        Center(child: Text('Không có yêu cầu chờ duyệt')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pending.length,
                      itemBuilder: (_, i) {
                        final n = _pending[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.jobTitle.isNotEmpty
                                      ? n.jobTitle
                                      : 'Công việc ${n.jobId.substring(0, 8)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${n.amount.toStringAsFixed(0)}₫ · ${n.workDate}',
                                ),
                                Text(
                                  'Gửi: ${DateFormat('dd/MM/yyyy HH:mm').format(n.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () => _approve(n),
                                        child: const Text('Cho phép GN'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _reject(n),
                                      icon: const Icon(Icons.close, color: Colors.red),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: () => _closeGroup(n),
                                  icon: const Icon(Icons.group_off_outlined),
                                  label: const Text('Đóng nhóm (không giải ngân)'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
