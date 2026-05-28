import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../common/styles/app_colors.dart';
import '../../controller/login_controller.dart';
import '../../data/models/disbursement_notice_model.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/services/job_attendance_completion_service.dart';
import '../../data/services/job_workflow_service.dart';
import '../../routes/app_routes.dart';

/// Khiếu nại (danh mục) → yêu cầu giải ngân → Admin duyệt → NTD giải ngân → đánh giá.
class JobDayEndFlowScreen extends StatefulWidget {
  const JobDayEndFlowScreen({super.key});

  @override
  State<JobDayEndFlowScreen> createState() => _JobDayEndFlowScreenState();
}

class _JobDayEndFlowScreenState extends State<JobDayEndFlowScreen> {
  final _workflow = JobWorkflowService();
  final _completionSvc = JobAttendanceCompletionService();
  final _auth = Get.find<AuthController>();

  late GroupChatModel _group;
  late String _workDate;
  int _step = 0;
  bool _submitting = false;
  final _amountCtrl = TextEditingController();
  String? _selectedCandidateId;
  double _rating = 4;
  final _commentCtrl = TextEditingController();
  DisbursementNoticeModel? _activeRequest;
  JobDisbursementReadiness? _readiness;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    _group = args['group'] as GroupChatModel;
    _workDate = args['workDate'] as String? ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    _verifyThenStart();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyThenStart() async {
    final candidateIds = _group.memberIds
        .where((id) => id.isNotEmpty && id != _group.employerId)
        .toList();
    final readiness = await _completionSvc.evaluate(
      jobId: _group.jobId,
      groupId: _group.groupId,
      candidateIds: candidateIds,
    );
    if (!mounted) return;
    if (!readiness.canRequestDisbursement) {
      Get.back();
      Get.snackbar(
        'Chưa thể giải ngân',
        readiness.message,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }
    _readiness = readiness;
    _activeRequest = await _workflow.getActiveRequestForJob(_group.jobId);
    if (_activeRequest != null) {
      _amountCtrl.text = _activeRequest!.amount.toStringAsFixed(0);
      setState(() => _step = 1);
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _submitRequest() async {
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
            0;
    if (amount <= 0) {
      Get.snackbar('Lỗi', 'Nhập số tiền giải ngân hợp lệ');
      return;
    }
    setState(() => _submitting = true);
    try {
      final id = await _workflow.requestDisbursement(
        jobId: _group.jobId,
        groupId: _group.groupId,
        employerId: _auth.currentUser?.id ?? _group.employerId,
        workDate: _workDate,
        amount: amount,
        jobTitle: _group.jobTitle,
      );
      _activeRequest = await _workflow.getActiveRequestForJob(_group.jobId);
      if (_activeRequest == null && id.isNotEmpty) {
        final snap = await _workflow.getActiveRequestForJob(_group.jobId);
        _activeRequest = snap;
      }
      Get.snackbar(
        'Đã gửi yêu cầu',
        'Admin sẽ duyệt trước khi bạn được giải ngân.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      if (mounted) setState(() {});
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmDisbursement() async {
    final req = _activeRequest;
    if (req == null || !req.canEmployerDisburse) return;
    setState(() => _submitting = true);
    try {
      await _workflow.executeDisbursement(req.noticeId);
      Get.snackbar('Đã giải ngân', 'Hoàn tất thanh toán',
          backgroundColor: Colors.green, colorText: Colors.white);
      if (mounted) setState(() => _step = 2);
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitRating() async {
    final cid = _selectedCandidateId;
    if (cid == null || cid.isEmpty) {
      Get.snackbar('Lỗi', 'Chọn nhân viên để đánh giá');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _workflow.submitEmployerRating(
        jobId: _group.jobId,
        candidateId: cid,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );
      Get.back(result: true);
      Get.snackbar('Hoàn tất', 'Đã đánh giá nhân viên',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<String> get _candidateIds =>
      _group.memberIds.where((id) => id != _group.employerId).toList();

  Widget _buildAttendanceWarning() {
    final r = _readiness!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              r.message,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisbursementStep() {
    return StreamBuilder<DisbursementNoticeModel?>(
      stream: _workflow.streamActiveRequestForJob(_group.jobId),
      builder: (context, snap) {
        final req = snap.data ?? _activeRequest;
        if (req == null) {
          return _buildRequestForm();
        }
        if (req.isWaitingAdmin) {
          return _buildWaitingAdmin(req);
        }
        if (req.canEmployerDisburse) {
          return _buildExecuteDisbursement(req);
        }
        return _buildRequestForm();
      },
    );
  }

  Widget _buildRequestForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Yêu cầu giải ngân — ${_group.jobTitle}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 8),
        const Text(
          'Admin phải duyệt trước. Sau khi được phép, bạn mới xác nhận đã giải ngân.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Số tiền đề nghị giải ngân (VNĐ) *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _submitting ? null : _submitRequest,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.employerPrimary,
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(_submitting ? 'Đang gửi...' : 'Gửi yêu cầu tới Admin'),
        ),
      ],
    );
  }

  Widget _buildWaitingAdmin(DisbursementNoticeModel req) {
    return Column(
      children: [
        const Icon(Icons.hourglass_top, size: 56, color: Color(0xFFEF6C00)),
        const SizedBox(height: 16),
        const Text(
          'Đang chờ Admin duyệt',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          'Số tiền: ${req.amount.toStringAsFixed(0)}₫\n'
          'Bạn sẽ nhận thông báo khi Admin cho phép giải ngân.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Get.toNamed(AppRoutes.complaintsCatalog),
          icon: const Icon(Icons.gavel_outlined),
          label: const Text('Xem danh mục khiếu nại'),
        ),
      ],
    );
  }

  Widget _buildExecuteDisbursement(DisbursementNoticeModel req) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: const Color(0xFFE8F5E9),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.verified_outlined,
                    color: Color(0xFF2E7D32), size: 40),
                const SizedBox(height: 8),
                const Text(
                  'Admin đã cho phép giải ngân',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  '${req.amount.toStringAsFixed(0)}₫ — ${_group.jobTitle}',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _submitting ? null : _confirmDisbursement,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.employerPrimary,
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(
            _submitting ? 'Đang xử lý...' : 'Xác nhận đã giải ngân',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.employerGradient),
        ),
        foregroundColor: Colors.white,
        title: Text(
          _step == 2
              ? 'Đánh giá nhân viên'
              : _step == 1
                  ? 'Giải ngân'
                  : 'Kết thúc ca',
        ),
      ),
      body: _step < 1
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_step == 1 && _readiness != null && !_readiness!.canDisburse)
                  _buildAttendanceWarning(),
                if (_step == 1) _buildDisbursementStep(),
                if (_step == 2) ...[
                  const Text(
                    'Đánh giá nhân viên',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCandidateId,
                    decoration: const InputDecoration(
                      labelText: 'Chọn nhân viên *',
                      border: OutlineInputBorder(),
                    ),
                    items: _candidateIds
                        .map((id) =>
                            DropdownMenuItem(value: id, child: Text(id)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCandidateId = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return IconButton(
                        icon: Icon(
                          star <= _rating.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFF57F17),
                          size: 36,
                        ),
                        onPressed: () =>
                            setState(() => _rating = star.toDouble()),
                      );
                    }),
                  ),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nhận xét (tùy chọn)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submitRating,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.employerPrimary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      _submitting ? 'Đang gửi...' : 'Gửi đánh giá & hoàn tất',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
