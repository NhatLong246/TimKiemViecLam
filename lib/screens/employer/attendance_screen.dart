import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/attendance_controller.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/services/attendance_auto_notify_service.dart';
import '../../data/services/group_chat_service.dart';
import '../../data/services/job_attendance_completion_service.dart';
import '../../routes/app_routes.dart';
import '../../widgets/attendance_photo_info.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AttendanceScreen — Điểm danh nhân viên
// Arguments: Map { 'groupId', 'jobId', 'jobTitle', 'memberIds' }
// ─────────────────────────────────────────────────────────────────────────────
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final AttendanceController _ctrl;
  late final String _groupId;
  late final String _jobId;
  late final String _jobTitle;
  late final List<String> _memberIds;
  late final String _employerId;
  final _timeCtrl = TextEditingController(text: '08:00');
  final _groupChatSvc = GroupChatService();
  final _autoNotify = AttendanceAutoNotifyService.instance;
  final _completionSvc = JobAttendanceCompletionService();
  List<UserModel>? _members;
  GroupChatModel? _group;
  Timer? _autoTimer;
  JobDisbursementReadiness? _readiness;

  List<String> get _candidateIds => _memberIds
      .where((id) => id.isNotEmpty && id != _employerId)
      .toList();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(AttendanceController());
    final args = Get.arguments as Map<String, dynamic>;
    _groupId = args['groupId'] as String;
    _jobId = args['jobId'] as String;
    _jobTitle = args['jobTitle'] as String;
    _memberIds = List<String>.from(args['memberIds'] as List? ?? []);
    _employerId = (args['employerId'] ?? '').toString();

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _ctrl.loadSessionByDate(_jobId, today);
    _loadMembers();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupAutoAttendance());
  }

  Future<void> _setupAutoAttendance() async {
    _group = await _groupChatSvc.getGroup(_groupId);
    if (_group == null) return;

    final shift = await _autoNotify.resolveShiftForDisplay(_groupId);
    if (mounted) _timeCtrl.text = shift.start;

    await _autoNotify.onEmployerOpensAttendance(_group!);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _ctrl.loadSessionByDate(_jobId, today);
    await _refreshDisbursementReadiness();

    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (_group == null) return;
      await _autoNotify.runScheduledForGroup(_group!);
      if (mounted && _ctrl.currentSession.value == null) {
        final t = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await _ctrl.loadSessionByDate(_jobId, t);
      }
      if (mounted) await _refreshDisbursementReadiness();
    });
  }

  Future<void> _refreshDisbursementReadiness() async {
    final readiness = await _completionSvc.evaluate(
      jobId: _jobId,
      groupId: _groupId,
      candidateIds: _candidateIds,
    );
    if (mounted) setState(() => _readiness = readiness);
  }

  Future<void> _loadMembers() async {
    var ids = _memberIds;
    var employerId = _employerId;
    if (employerId.isEmpty) {
      final g = await _groupChatSvc.getGroup(_groupId);
      employerId = g?.employerId ?? '';
    }
    final list = await _groupChatSvc.getGroupMembers(ids);
    if (mounted) {
      setState(() {
        _members = list;
        if (_employerId.isEmpty) _employerId = employerId;
      });
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _timeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Obx(() {
        if (_ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_ctrl.currentSession.value == null) {
          return _buildNoSession();
        }
        return _buildSessionView();
      }),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.employerPrimary,
      flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.employerGradient)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: Get.back,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Điểm danh',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(_jobTitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ── Chưa có phiên hôm nay ────────────────────────────────────────────────
  Widget _buildNoSession() {
    final today = DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.now());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateHeader(date: today),
          const SizedBox(height: 24),
          const Text('Giờ bắt đầu ca',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          _TimePickerField(controller: _timeCtrl),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.employerPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.employerPrimary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Nhấn "Bắt đầu điểm danh" để tạo phiên và tự gửi thông báo '
                    'cho nhân viên. Đến giờ ca (phân công công việc), hệ thống '
                    'cũng tự gửi nếu bạn chưa bấm bắt đầu.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.employerGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: _startSession,
                child: const Text('Bắt đầu điểm danh',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Đã có phiên → bảng 3 cột ────────────────────────────────────────────
  Widget _buildSessionView() {
    return Column(
      children: [
        // Header ngày + ca
        _buildSessionHeader(),
        // Nút thông báo hàng loạt
        _buildNotifyBar(),
        // Bảng 3 cột
        Expanded(
          child: Obx(() {
            final records = _ctrl.editRecords;
            if (records.isEmpty) {
              return Center(
                child: Text('Không có nhân viên trong nhóm',
                    style: TextStyle(color: Colors.grey.shade600)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              itemCount: records.length,
              itemBuilder: (_, i) => _AttendanceRow(
                record: records[i],
                index: i,
                ctrl: _ctrl,
                groupId: _groupId,
                groupChatSvc: _groupChatSvc,
              ),
            );
          }),
        ),
        _buildDayEndBar(),
        _buildSaveBar(),
      ],
    );
  }

  Widget _buildDayEndBar() {
    final r = _readiness;
    if (r == null || r.requiredDays == 0) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            r.message,
            style: TextStyle(
              fontSize: 13,
              color: r.canDisburse ? const Color(0xFF2E7D32) : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (r.requiredDays > 1) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: r.requiredDays > 0 ? r.completedDays / r.requiredDays : 0,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.employerPrimary,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          const SizedBox(height: 8),
          if (r.canDisburse)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openDisbursementFlow(),
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  r.requiredDays == 1
                      ? 'Giải ngân & đánh giá'
                      : 'Giải ngân (${r.requiredDays} ngày đã xong)',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.employerPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else if (r.canRequestDisbursement)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openDisbursementFlow(),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Gửi yêu cầu giải ngân (Admin xem xét)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.employerPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_clock_outlined),
              label: Text(
                r.requiredDays == 1
                    ? 'Chưa đủ điểm danh trong ngày'
                    : 'Còn ${r.requiredDays - r.completedDays} ngày trong lịch',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openDisbursementFlow() async {
    if (_group == null) return;
    await _refreshDisbursementReadiness();
    final r = _readiness;
    if (r == null || !r.canRequestDisbursement) {
      Get.snackbar(
        'Chưa thể giải ngân',
        r?.message ?? 'Hoàn tất điểm danh trong thời hạn làm việc.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }
    final lastDate = r.mandatoryDates.isNotEmpty
        ? r.mandatoryDates.last
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await Get.toNamed(
      AppRoutes.jobDayEndFlow,
      arguments: {'group': _group!, 'workDate': lastDate},
    );
    if (result == true && mounted) await _refreshDisbursementReadiness();
  }

  Widget _buildSessionHeader() {
    final session = _ctrl.currentSession.value!;
    final date = session.date;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                gradient: AppColors.employerGradient,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.calendar_today,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, dd/MM/yyyy', 'vi')
                      .format(DateTime.parse(date)),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text('Bắt đầu: ${session.expectedStartTime}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          // Thống kê nhanh
          Obx(() => Row(
                children: [
                  _MiniChip(
                      label: '${_ctrl.totalOnTime}',
                      color: const Color(0xFF2E7D32)),
                  const SizedBox(width: 4),
                  _MiniChip(
                      label: '${_ctrl.totalLate}',
                      color: const Color(0xFFEF6C00)),
                  const SizedBox(width: 4),
                  _MiniChip(
                      label: '${_ctrl.totalAbsent}',
                      color: const Color(0xFFC62828)),
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildNotifyBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: _NotifyButton(
              label: 'Thông báo đầu ca',
              icon: Icons.login_rounded,
              color: const Color(0xFF1565C0),
              onTap: () => _notifyAll(isCheckIn: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NotifyButton(
              label: 'Thông báo cuối ca',
              icon: Icons.logout_rounded,
              color: const Color(0xFF2E7D32),
              onTap: () => _notifyAll(isCheckIn: false),
            ),
          ),
        ],
      ),
    );
  }

  // Gửi thông báo điểm danh tất cả nhân viên qua group chat
  Future<void> _notifyAll({required bool isCheckIn}) async {
    final type = isCheckIn ? 'đầu ca' : 'cuối ca';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Thông báo điểm danh $type',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Gửi thông báo đến tất cả nhân viên để điểm danh $type?'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Hủy',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.employerPrimary),
            onPressed: () => Get.back(result: true),
            child: const Text('Gửi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final session = _ctrl.currentSession.value;
    if (session == null) return;

    for (final r in _ctrl.editRecords) {
      if (r.candidateId.isEmpty) continue;
      await _groupChatSvc.sendAttendanceRequest(
        groupId: _groupId,
        jobId: _jobId,
        attendanceId: session.attendanceId,
        targetUserId: r.candidateId,
        targetName: r.candidateName.isNotEmpty
            ? r.candidateName
            : 'Nhân viên',
        isCheckIn: isCheckIn,
        expectedStartTime: session.expectedStartTime,
        allowDuplicate: true,
      );
    }

    await _refreshDisbursementReadiness();
    Get.snackbar('Đã gửi', 'Thông báo điểm danh $type đã được gửi',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white);
  }

  Widget _buildSaveBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Obx(() => SizedBox(
            width: double.infinity,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.employerGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: _ctrl.isSaving.value
                    ? null
                    : () async {
                        await _ctrl.saveAll();
                        await _refreshDisbursementReadiness();
                      },
                child: _ctrl.isSaving.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Lưu điểm danh',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
              ),
            ),
          )),
    );
  }

  Future<void> _startSession() async {
    final workers = (_members ?? [])
        .where((u) => u.id != _employerId)
        .map((u) => AttendanceRecord(
              candidateId: u.id,
              candidateName:
                  '${u.firstName} ${u.lastName}'.trim(),
              status: 'not_marked',
              lateMinutes: 0,
            ))
        .toList();

    await _ctrl.startSession(
      jobId: _jobId,
      groupId: _groupId,
      workers: workers,
      expectedStartTime: _timeCtrl.text,
    );

    final session = _ctrl.currentSession.value;
    _group ??= await _groupChatSvc.getGroup(_groupId);
    if (session != null && _group != null) {
      await _autoNotify.onEmployerStartedSession(
        group: _group!,
        session: session,
      );
      if (mounted) {
        Get.snackbar(
          'Đã bắt đầu',
          'Đã tạo phiên và gửi thông báo đầu ca cho nhân viên',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    }
  }
}

// ── Widgets phụ ───────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              gradient: AppColors.employerGradient,
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.calendar_today,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hôm nay',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            Text(date,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ],
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          builder: (ctx, child) => Theme(
            data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                    primary: AppColors.employerPrimary)),
            child: child!,
          ),
        );
        if (picked != null) {
          controller.text =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        }
      },
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.access_time),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            hintText: 'Chọn giờ bắt đầu',
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _NotifyButton extends StatelessWidget {
  const _NotifyButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hàng điểm danh (3 cột) ────────────────────────────────────────────────────
class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.record,
    required this.index,
    required this.ctrl,
    required this.groupId,
    required this.groupChatSvc,
  });
  final AttendanceRecord record;
  final int index;
  final AttendanceController ctrl;
  final String groupId;
  final GroupChatService groupChatSvc;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Tên nhân viên + trạng thái tổng
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      AppColors.employerPrimary.withOpacity(0.12),
                  child: Text(
                    record.candidateName.isNotEmpty
                        ? record.candidateName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.employerPrimary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    record.candidateName.isNotEmpty
                        ? record.candidateName
                        : 'Nhân viên',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                _StatusBadge(status: record.status),
              ],
            ),
            const SizedBox(height: 10),
            // Hai cột: Đầu ca | Cuối ca
            Row(
              children: [
                Expanded(
                  child: _PhotoCell(
                    label: 'Đầu ca',
                    photoBase64: record.checkInPhotoUrl,
                    time: record.checkInTime,
                    capturedAt: record.checkInCapturedAt,
                    locationLabel: record.checkInLocation,
                    fileName: record.checkInPhotoName,
                    icon: Icons.login_rounded,
                    color: const Color(0xFF1565C0),
                    onNotify: () => _notify(context, isCheckIn: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PhotoCell(
                    label: 'Cuối ca',
                    photoBase64: record.checkOutPhotoUrl,
                    time: record.checkOutTime,
                    capturedAt: record.checkOutCapturedAt,
                    locationLabel: record.checkOutLocation,
                    fileName: record.checkOutPhotoName,
                    icon: Icons.logout_rounded,
                    color: const Color(0xFF2E7D32),
                    onNotify: () => _notify(context, isCheckIn: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Trạng thái buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Trạng thái: ',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                ..._buildStatusButtons(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatusButtons() {
    const statuses = ['on_time', 'late', 'absent'];
    const labels = ['Đúng giờ', 'Trễ', 'Vắng'];
    const colors = [
      Color(0xFF2E7D32),
      Color(0xFFEF6C00),
      Color(0xFFC62828)
    ];

    return List.generate(3, (i) {
      final isSelected = record.status == statuses[i];
      return GestureDetector(
        onTap: () => ctrl.markStatus(index, statuses[i]),
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: isSelected
                  ? colors[i].withOpacity(0.15)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: colors[i].withOpacity(0.5))
                  : null),
          child: Text(labels[i],
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? colors[i] : Colors.grey.shade500)),
        ),
      );
    });
  }

  Future<void> _notify(BuildContext context,
      {required bool isCheckIn}) async {
    final type = isCheckIn ? 'đầu ca' : 'cuối ca';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Thông báo điểm danh $type',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Thông báo cho "${record.candidateName}" đến lúc điểm danh $type?'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Hủy',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.employerPrimary),
            onPressed: () => Get.back(result: true),
            child: const Text('Gửi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final session = ctrl.currentSession.value;
    if (session == null) return;

    await groupChatSvc.sendAttendanceRequest(
      groupId: groupId,
      jobId: session.jobId,
      attendanceId: session.attendanceId,
      targetUserId: record.candidateId,
      targetName:
          record.candidateName.isNotEmpty ? record.candidateName : 'Nhân viên',
      isCheckIn: isCheckIn,
      expectedStartTime: session.expectedStartTime,
      allowDuplicate: true,
    );

    Get.snackbar('Đã gửi', 'Thông báo đã được gửi đến ${record.candidateName}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2));
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'on_time':
        color = const Color(0xFF2E7D32);
        label = 'Đúng giờ';
        break;
      case 'late':
        color = const Color(0xFFEF6C00);
        label = 'Trễ';
        break;
      case 'absent':
        color = const Color(0xFFC62828);
        label = 'Vắng';
        break;
      default:
        color = Colors.grey;
        label = 'Chờ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// Ô hiển thị ảnh điểm danh
class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    required this.label,
    required this.photoBase64,
    required this.time,
    this.capturedAt,
    this.locationLabel,
    this.fileName,
    required this.icon,
    required this.color,
    required this.onNotify,
  });
  final String label;
  final String? photoBase64;
  final String? time;
  final String? capturedAt;
  final String? locationLabel;
  final String? fileName;
  final IconData icon;
  final Color color;
  final VoidCallback onNotify;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        bytes = base64Decode(photoBase64!);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
          const SizedBox(height: 6),
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(bytes,
                  width: double.infinity,
                  height: 72,
                  fit: BoxFit.cover),
            )
          else
            GestureDetector(
              onTap: onNotify,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        color: color, size: 18),
                    const SizedBox(height: 2),
                    Text('Thông báo',
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          AttendancePhotoInfo(
            capturedAt: capturedAt,
            time: time,
            locationLabel: locationLabel,
            fileName: fileName,
            textColor: color,
            dense: true,
          ),
        ],
      ),
    );
  }
}

