import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../common/styles/app_colors.dart';
import '../../controller/login_controller.dart';
import '../../data/models/disbursement_notice_model.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/group_chat_service.dart';
import '../../data/services/job_attendance_completion_service.dart';
import '../../data/services/job_workflow_service.dart';
import '../../data/services/file_upload_service.dart';
import '../../routes/app_routes.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class JobDayEndFlowScreen extends StatefulWidget {
  const JobDayEndFlowScreen({super.key});

  @override
  State<JobDayEndFlowScreen> createState() => _JobDayEndFlowScreenState();
}

class _JobDayEndFlowScreenState extends State<JobDayEndFlowScreen> {
  final _workflow = JobWorkflowService();
  final _completionSvc = JobAttendanceCompletionService();
  final _groupChatSvc = GroupChatService();
  final _auth = Get.find<AuthController>();

  late GroupChatModel _group;
  late String _workDate;

  List<UserModel> _candidates = [];
  bool _loading = true;
  bool _submitting = false;

  Map<String, double> _calculatedSalaries = {};
  double _totalEarned = 0;

  final _amountCtrl = TextEditingController();

  // Rating state
  final Map<String, double> _ratings = {};
  final Map<String, TextEditingController> _comments = {};

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    _group = args['group'] as GroupChatModel;
    _workDate =
        args['workDate'] as String? ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final candidateIds = _group.memberIds
          .where((id) => id.isNotEmpty && id != _group.employerId)
          .toList();

      final readiness = await _completionSvc.evaluate(
        jobId: _group.jobId,
        groupId: _group.groupId,
        candidateIds: candidateIds,
      );

      _calculatedSalaries = await _completionSvc.calculateCandidateSalaries(
        jobId: _group.jobId,
        candidateIds: candidateIds,
      );
      _totalEarned = _calculatedSalaries.values.fold(0.0, (a, b) => a + b);

      // Lấy thông tin số tiền tạm giữ (tiền ứng) của công việc
      final jobDoc = await FirebaseFirestore.instance
          .collection('jobPosts')
          .doc(_group.jobId)
          .get();
      final depositHeld = (jobDoc.data()?['depositStatus'] ?? '').toString() == 'held';
      final heldAmount = depositHeld ? (jobDoc.data()?['totalBudget'] as num?)?.toDouble() ?? 0.0 : 0.0;

      // Mặc định điền vào ô Giải ngân là số tiền tạm giữ thay vì 0 VNĐ
      _amountCtrl.text = heldAmount.toStringAsFixed(0);

      _candidates = await _groupChatSvc.getGroupMembers(candidateIds);

      if (mounted) setState(() => _loading = false);

      // BYPASS: Bỏ qua validate chặn giải ngân (khi chưa đủ điều kiện điểm danh) để test
      /*
      if (!readiness.canRequestDisbursement) {
        Get.back();
        Get.snackbar(
          'Chưa thể giải ngân',
          readiness.message,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
      */
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════
  // BƯỚC 1: NTD NHẬP SỐ TIỀN → TẠO YÊU CẦU
  // ═══════════════════════════════════════════════════════

  Future<void> _submitRequest() async {
    final amount =
        double.tryParse(
          _amountCtrl.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;
    
    // BYPASS: Bỏ qua validate phải giải ngân đúng bằng thời gian thực tế
    /*
    if (amount <= 0 || amount < _totalEarned) {
      Get.snackbar(
        'Lỗi',
        'Tổng lương nhân viên là ${_totalEarned.toStringAsFixed(0)}₫. Bạn phải nhập số tiền tối thiểu bằng mức này.',
      );
      return;
    }
    */
    setState(() => _submitting = true);
    try {
      final empId = _auth.currentUser?.id ?? _group.employerId;

      // Lấy thông tin jobPost để biết heldAmount
      final jobDoc = await FirebaseFirestore.instance
          .collection('jobPosts')
          .doc(_group.jobId)
          .get();
      final depositHeld =
          (jobDoc.data()?['depositStatus'] ?? '').toString() == 'held';
      final heldAmount = depositHeld
          ? (jobDoc.data()?['totalBudget'] as num?)?.toDouble() ?? 0.0
          : 0.0;

      final needToPayExtra = (amount - heldAmount).clamp(0.0, double.infinity);

      // Lấy số dư ví mới nhất
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(empId)
          .get();
      final walletBalance =
          (userDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;

      // BYPASS: Bỏ qua kiểm tra số dư ví NTD để cho phép test luồng tiếp theo
      /*
      if (needToPayExtra > walletBalance) {
        if (mounted) setState(() => _submitting = false);
        Get.snackbar(
          'Số dư không đủ',
          'Bạn cần đóng thêm ${needToPayExtra.toStringAsFixed(0)}₫. Ví của bạn chỉ còn ${walletBalance.toStringAsFixed(0)}₫. Vui lòng nạp thêm tiền.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return;
      }
      */

      // Đảm bảo tổng chia cho ứng viên không vượt quá số tiền giải ngân (amount)
      // Chia theo tỷ lệ lương đã tính (dựa trên điểm danh)
      final proportionalAmounts = <String, double>{};
      final totalCalc = _calculatedSalaries.values.fold(0.0, (a, b) => a + b);
      
      if (totalCalc > 0) {
        for (final entry in _calculatedSalaries.entries) {
          proportionalAmounts[entry.key] = (entry.value / totalCalc) * amount;
        }
      } else {
        // Nếu không ai có điểm danh hợp lệ nhưng NTD vẫn giải ngân, chia đều
        final count = _candidates.where((c) => c.id != _group.employerId).length;
        final split = count > 0 ? amount / count : 0.0;
        for (final c in _candidates) {
          if (c.id != _group.employerId) {
            proportionalAmounts[c.id] = split;
          }
        }
      }

      await _workflow.requestDisbursement(
        jobId: _group.jobId,
        groupId: _group.groupId,
        employerId: empId,
        workDate: _workDate,
        amount: amount,
        totalEarned: amount, // Coi như giải ngân hết số amount, không có tiền thừa
        candidateAmounts: proportionalAmounts,
        jobTitle: _group.jobTitle,
      );
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ═══════════════════════════════════════════════════════
  // BƯỚC 2: HIỆN DIALOG "CÓ MUỐN KHIẾU NẠI KHÔNG?"
  // ═══════════════════════════════════════════════════════

  Future<void> _showComplaintOrDisburseDialog(
    DisbursementNoticeModel req,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Giải ngân'),
        content: const Text(
          'Bạn có muốn khiếu nại ứng viên nào không?\n\n'
          '• Nếu KHÔNG → Tiền sẽ được chia đều cho tất cả ứng viên ngay.\n'
          '• Nếu CÓ → Chọn ứng viên để gửi khiếu nại tới Admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không, giải ngân luôn'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Có, tôi muốn khiếu nại'),
          ),
        ],
      ),
    );

    if (result == true) {
      // Chuyển sang màn hình chọn user khiếu nại
      if (mounted) {
        _navigateToSelectComplaintUser(req);
      }
    } else if (result == false) {
      // Giải ngân trực tiếp
      await _directDisburse(req);
    }
  }

  Future<void> _directDisburse(DisbursementNoticeModel req) async {
    setState(() => _submitting = true);
    try {
      await _workflow.disburseDirectly(req.noticeId);
      Get.snackbar(
        'Hoàn tất',
        'Đã giải ngân chia tiền cho tất cả ứng viên!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      // Hỏi đánh giá
      _showRatingDialog(req);
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ═══════════════════════════════════════════════════════
  // MÀN HÌNH CHỌN USER ĐỂ KHIẾU NẠI
  // ═══════════════════════════════════════════════════════

  void _navigateToSelectComplaintUser(DisbursementNoticeModel req) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SelectComplaintUserScreen(
          candidates: _candidates,
          req: req,
          workflow: _workflow,
          onDone: () {
            // Sau khi gửi xong khiếu nại → quay lại để chờ admin duyệt
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // GIẢI NGÂN SAU KHIẾU NẠI (Admin đã duyệt)
  // ═══════════════════════════════════════════════════════

  Future<void> _disburseAfterComplaint(DisbursementNoticeModel req) async {
    setState(() => _submitting = true);
    try {
      await _workflow.disburseAfterComplaint(req.noticeId);
      Get.snackbar(
        'Hoàn tất',
        'Đã giải ngân sau khi xử lý khiếu nại!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      _showRatingDialog(req);
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ═══════════════════════════════════════════════════════
  // DIALOG HỎI ĐÁNH GIÁ SAU KHI GIẢI NGÂN XONG
  // ═══════════════════════════════════════════════════════

  Future<void> _showRatingDialog(DisbursementNoticeModel req) async {
    if (!mounted) return;
    final wantRate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Đánh giá ứng viên'),
        content: const Text(
          'Bạn có muốn đánh giá ứng viên trong ca làm này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Có, đánh giá'),
          ),
        ],
      ),
    );

    if (wantRate == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _RatingScreen(
            candidates: _candidates,
            jobId: req.jobId,
            jobTitle: req.jobTitle,
            workflow: _workflow,
          ),
        ),
      );
    } else {
      // Chuyển tới tab Đã HT trong PostManagementScreen
      Get.offNamedUntil(
        AppRoutes.postManagement,
        (route) => route.settings.name == AppRoutes.employerHome || route.isFirst,
        arguments: {'initialTab': 4},
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  // BUILD UI
  // ═══════════════════════════════════════════════════════

  Widget _buildStepRequestForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Giải ngân',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        const SizedBox(height: 8),
        const Text(
          'Hệ thống sẽ tự động tính toán lương dựa trên thời gian làm việc thực tế. '
          'Nếu số tiền giải ngân ít hơn số tiền tạm giữ, phần dư sẽ được hoàn lại vào ví của bạn.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.payments_outlined, color: Colors.green.shade700, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng số tiền giải ngân',
                      style: TextStyle(color: Colors.green.shade800, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_amountCtrl.text} VNĐ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Số nhân viên: ${_candidates.length}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _submitting ? null : _submitRequest,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.employerPrimary,
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: Text(_submitting ? 'Đang xử lý...' : 'Xác nhận giải ngân'),
        ),
      ],
    );
  }

  Widget _buildStepApproved(DisbursementNoticeModel req) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          'Tổng tiền: ${req.amount.toStringAsFixed(0)}₫',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        // Liệt kê chi tiết từng người nhận
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chi tiết phân bổ:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...req.candidateAmounts.entries.map((e) {
                final user = _candidates.firstWhereOrNull((c) => c.id == e.key);
                final name = user != null ? '${user.firstName} ${user.lastName}' : 'Ứng viên';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 14)),
                      Text(
                        '${e.value.toStringAsFixed(0)}₫',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _submitting
              ? null
              : () => _showComplaintOrDisburseDialog(req),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.employerPrimary,
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.monetization_on_outlined),
          label: const Text(
            'Tiến hành giải ngân',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildStepComplaintsPending(DisbursementNoticeModel req) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.gavel, size: 64, color: Colors.deepPurple),
        const SizedBox(height: 16),
        const Text(
          'Đang chờ Admin xem xét khiếu nại',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Khiếu nại của bạn đã được gửi tới Admin.\nVui lòng chờ Admin xem xét và phản hồi.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        // Hiện danh sách ai bị khiếu nại
        ...req.complainedCandidates.map((cid) {
          final user = _candidates.firstWhereOrNull((c) => c.id == cid);
          final name = user != null
              ? '${user.firstName} ${user.lastName}'
              : cid.substring(0, 8);
          final reason = req.complaintReasons[cid] ?? '';
          final amount = req.deductions[cid] ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.red),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Lý do: $reason\nĐề xuất đền bù: ${amount.toStringAsFixed(0)}₫',
              ),
              isThreeLine: true,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepComplaintsReviewed(DisbursementNoticeModel req) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.task_alt, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'Admin đã xem xét khiếu nại',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.green,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (req.adminNote.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Ghi chú Admin: ${req.adminNote}'),
          ),
          const SizedBox(height: 16),
        ],
        // Hiện kết quả từng khiếu nại
        ...req.complainedCandidates.map((cid) {
          final user = _candidates.firstWhereOrNull((c) => c.id == cid);
          final name = user != null
              ? '${user.firstName} ${user.lastName}'
              : cid.substring(0, 8);
          final result = req.complaintResults[cid] ?? 'pending';
          final isApproved = result == 'approved';
          final finalAmt = req.adminFinalDeductions[cid] ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isApproved ? Colors.red.shade50 : Colors.green.shade50,
            child: ListTile(
              leading: Icon(
                isApproved ? Icons.check_circle : Icons.cancel,
                color: isApproved ? Colors.red : Colors.green,
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                isApproved
                    ? 'Duyệt — Đền bù: ${finalAmt.toStringAsFixed(0)}₫'
                    : 'Từ chối — Không trừ tiền',
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        // Bảng tóm tắt tiền từng người nhận
        const Divider(),
        const Text(
          'Bảng lương sau xử lý:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ..._candidates.map((c) {
          final wage = req.candidateAmounts[c.id] ?? 0;
          final deduction = req.adminFinalDeductions[c.id] ?? 0;
          final received = (wage - deduction).clamp(0, double.infinity);
          return Card(
            child: ListTile(
              title: Text('${c.firstName} ${c.lastName}'),
              subtitle: Text(
                'Lương: ${wage.toStringAsFixed(0)}₫ | Trừ: ${deduction.toStringAsFixed(0)}₫',
              ),
              trailing: Text(
                '${received.toStringAsFixed(0)}₫',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _submitting ? null : () => _disburseAfterComplaint(req),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: Text(
            _submitting ? 'Đang xử lý...' : 'Giải ngân ngay',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildStepCompleted() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.check_circle, size: 80, color: Colors.green),
        SizedBox(height: 16),
        Text(
          'Đã giải ngân hoàn tất',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        SizedBox(height: 12),
        Text(
          'Nhóm chat đã được đóng và tiền đã chia về ví ứng viên.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.employerGradient),
        ),
        foregroundColor: Colors.white,
        title: const Text('Giải ngân & Kết thúc ca'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DisbursementNoticeModel?>(
              stream: _workflow.streamActiveRequestForJob(_group.jobId),
              builder: (context, snap) {
                final req = snap.data;

                Widget content;
                if (req == null) {
                  // Kiểm tra đã giải ngân chưa
                  return FutureBuilder<bool>(
                    future: _workflow.hasCompletedDisbursement(_group.jobId),
                    builder: (ctx, completedSnap) {
                      if (completedSnap.data == true) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildStepCompleted(),
                        );
                      }
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildStepRequestForm(),
                      );
                    },
                  );
                } else if (req.status == 'approved') {
                  content = _buildStepApproved(req);
                } else if (req.isComplaintsPending) {
                  content = _buildStepComplaintsPending(req);
                } else if (req.isComplaintsReviewed) {
                  content = _buildStepComplaintsReviewed(req);
                } else {
                  content = _buildStepCompleted();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: content,
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MÀN HÌNH CHỌN USER ĐỂ KHIẾU NẠI
// ═══════════════════════════════════════════════════════

class _SelectComplaintUserScreen extends StatefulWidget {
  final List<UserModel> candidates;
  final DisbursementNoticeModel req;
  final JobWorkflowService workflow;
  final VoidCallback onDone;

  const _SelectComplaintUserScreen({
    required this.candidates,
    required this.req,
    required this.workflow,
    required this.onDone,
  });

  @override
  State<_SelectComplaintUserScreen> createState() =>
      _SelectComplaintUserScreenState();
}

class _SelectComplaintUserScreenState
    extends State<_SelectComplaintUserScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.employerGradient),
        ),
        foregroundColor: Colors.white,
        title: const Text('Chọn ứng viên khiếu nại'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.candidates.length,
        itemBuilder: (_, i) {
          final c = widget.candidates[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: c.avatarUrl?.isNotEmpty == true
                    ? NetworkImage(c.avatarUrl!)
                    : null,
                child: c.avatarUrl?.isNotEmpty != true
                    ? Text(c.firstName.isNotEmpty ? c.firstName[0] : '?')
                    : null,
              ),
              title: Text(
                '${c.firstName} ${c.lastName}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Lương: ${(widget.req.candidateAmounts[c.id] ?? 0).toStringAsFixed(0)}₫',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ComplaintFormScreen(
                      candidate: c,
                      req: widget.req,
                      workflow: widget.workflow,
                      onSubmitted: () {
                        // Quay về trang trước
                        widget.onDone();
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MÀN HÌNH NHẬP KHIẾU NẠI CHO 1 ỨNG VIÊN
// ═══════════════════════════════════════════════════════

class _ComplaintFormScreen extends StatefulWidget {
  final UserModel candidate;
  final DisbursementNoticeModel req;
  final JobWorkflowService workflow;
  final VoidCallback onSubmitted;

  const _ComplaintFormScreen({
    required this.candidate,
    required this.req,
    required this.workflow,
    required this.onSubmitted,
  });

  @override
  State<_ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<_ComplaintFormScreen> {
  final _reasonCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final List<File> _evidenceImages = [];
  bool _submitting = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(limit: 3);
    if (images.isNotEmpty) {
      setState(() {
        for (var img in images) {
          if (_evidenceImages.length < 3) {
            _evidenceImages.add(File(img.path));
          }
        }
      });
    }
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    final amount =
        double.tryParse(
          _amountCtrl.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;

    if (reason.isEmpty) {
      Get.snackbar('Lỗi', 'Vui lòng nhập lý do khiếu nại');
      return;
    }
    if (amount <= 0) {
      Get.snackbar('Lỗi', 'Vui lòng nhập số tiền đền bù');
      return;
    }
    if (_evidenceImages.isEmpty) {
      Get.snackbar('Lỗi', 'Vui lòng cung cấp ít nhất 1 hình ảnh bằng chứng (tối đa 3 ảnh)');
      return;
    }

    setState(() => _submitting = true);
    try {
      List<String> evidenceUrls = [];
      for (final file in _evidenceImages) {
        final url = await FileUploadService.uploadAnonymous(file);
        evidenceUrls.add(url);
      }

      await widget.workflow.submitComplaint(
        noticeId: widget.req.noticeId,
        candidateId: widget.candidate.id,
        reason: reason,
        compensationAmount: amount,
        evidenceUrls: evidenceUrls,
      );
      Get.snackbar(
        'Đã gửi',
        'Khiếu nại đã được gửi tới Admin',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      widget.onSubmitted();
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wage = widget.req.candidateAmounts[widget.candidate.id] ?? 0;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.employerGradient),
        ),
        foregroundColor: Colors.white,
        title: const Text('Gửi khiếu nại'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thông tin ứng viên
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage:
                          widget.candidate.avatarUrl?.isNotEmpty == true
                          ? NetworkImage(widget.candidate.avatarUrl!)
                          : null,
                      child: widget.candidate.avatarUrl?.isNotEmpty != true
                          ? Text(
                              widget.candidate.firstName.isNotEmpty
                                  ? widget.candidate.firstName[0]
                                  : '?',
                              style: const TextStyle(fontSize: 24),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.candidate.firstName} ${widget.candidate.lastName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tiền công: ${wage.toStringAsFixed(0)}₫',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Lý do khiếu nại
            const Text(
              'Lý do khiếu nại *',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'VD: Đi trễ 2 tiếng, hư hỏng thiết bị...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Số tiền đền bù
            const Text(
              'Số tiền đền bù yêu cầu (VNĐ) *',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'VD: 100000',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.monetization_on_outlined),
                helperText:
                    'Tiền công ứng viên: ${wage.toStringAsFixed(0)}₫.\n'
                    'Nếu vượt tiền công, ứng viên sẽ phải bồi thường phần chênh lệch.',
              ),
            ),
            const SizedBox(height: 24),

            // Hình ảnh bằng chứng
            const Text(
              'Bằng chứng (Bắt buộc, tối đa 3 ảnh)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._evidenceImages.map((file) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          file,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _evidenceImages.remove(file);
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (_evidenceImages.length < 3)
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade100,
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: Colors.grey),
                          SizedBox(height: 4),
                          Text('Thêm ảnh', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _submitting ? 'Đang tải bằng chứng lên...' : 'Gửi khiếu nại tới Admin',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MÀN HÌNH ĐÁNH GIÁ SAU GIẢI NGÂN
// ═══════════════════════════════════════════════════════

class _RatingScreen extends StatefulWidget {
  final List<UserModel> candidates;
  final String jobId;
  final String jobTitle;
  final JobWorkflowService workflow;

  const _RatingScreen({
    required this.candidates,
    required this.jobId,
    required this.jobTitle,
    required this.workflow,
  });

  @override
  State<_RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<_RatingScreen> {
  final Map<String, double> _ratings = {};
  final Map<String, TextEditingController> _comments = {};
  final Set<String> _ratedIds = {};
  bool _submitting = false;

  Future<void> _submitRating(String candidateId) async {
    final r = _ratings[candidateId] ?? 4.0;
    final c = _comments[candidateId]?.text.trim() ?? '';

    setState(() => _submitting = true);
    try {
      await widget.workflow.submitEmployerRating(
        jobId: widget.jobId,
        candidateId: candidateId,
        rating: r,
        comment: c,
      );
      setState(() => _ratedIds.add(candidateId));
      Get.snackbar(
        'Thành công',
        'Đã đánh giá',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Xóa logic tự động back để user tự bấm nút Hoàn thành
      if (_ratedIds.length >= widget.candidates.length) {
        Get.snackbar('Tuyệt vời', 'Đã đánh giá tất cả ứng viên');
      }
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.employerGradient),
        ),
        foregroundColor: Colors.white,
        title: const Text('Đánh giá ứng viên'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Bỏ qua', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.candidates.length,
        itemBuilder: (_, i) {
          final c = widget.candidates[i];
          final isRated = _ratedIds.contains(c.id);
          _ratings.putIfAbsent(c.id, () => 4.0);
          _comments.putIfAbsent(c.id, () => TextEditingController());

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: c.avatarUrl?.isNotEmpty == true
                            ? NetworkImage(c.avatarUrl!)
                            : null,
                        child: c.avatarUrl?.isNotEmpty != true
                            ? Text(
                                c.firstName.isNotEmpty ? c.firstName[0] : '?',
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${c.firstName} ${c.lastName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isRated)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  if (!isRated) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (idx) {
                        final star = idx + 1;
                        return IconButton(
                          icon: Icon(
                            star <= (_ratings[c.id] ?? 4).round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: const Color(0xFFF57F17),
                            size: 32,
                          ),
                          onPressed: () =>
                              setState(() => _ratings[c.id] = star.toDouble()),
                        );
                      }),
                    ),
                    TextField(
                      controller: _comments[c.id],
                      decoration: const InputDecoration(
                        labelText: 'Nhận xét (tùy chọn)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _submitting ? null : () => _submitRating(c.id),
                      child: const Text('Gửi đánh giá'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF00B2FF), // AppColors.employerPrimary
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Get.offNamedUntil(
                AppRoutes.postManagement,
                (route) => route.settings.name == AppRoutes.employerHome || route.isFirst,
                arguments: {'initialTab': 4},
              );
              Get.snackbar(
                'Hoàn tất',
                'Quá trình giải ngân đã hoàn thành',
                backgroundColor: Colors.green,
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: const Text(
              'Hoàn thành giải ngân',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
