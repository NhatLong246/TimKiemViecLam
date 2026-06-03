import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/work_schedule_model.dart';
import '../../data/models/job_post_model.dart';
import '../../data/services/group_chat_service.dart';
import '../../data/services/work_schedule_service.dart';
import '../../data/services/job_post_service.dart';
import 'assigned_tasks_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WorkScheduleScreen — Phân công công việc (ca + nhiệm vụ theo ngày)
// Argument: GroupChatModel
// ─────────────────────────────────────────────────────────────────────────────
class WorkScheduleScreen extends StatefulWidget {
  const WorkScheduleScreen({super.key});

  @override
  State<WorkScheduleScreen> createState() => _WorkScheduleScreenState();
}

class _WorkScheduleScreenState extends State<WorkScheduleScreen> {
  late final GroupChatModel _group;
  final _service = WorkScheduleService();
  final _groupChatSvc = GroupChatService();
  final _jobSvc = JobPostService();

  DateTime _selectedDate = DateTime.now();
  final _shiftStartCtrl = TextEditingController(text: '08:00');
  final _shiftEndCtrl = TextEditingController(text: '17:00');
  final _generalCtrl = TextEditingController();
  final Map<String, TextEditingController> _taskCtrls = {};

  List<UserModel>? _members;
  WorkScheduleModel? _existing;
  JobPostModel? _jobPost;
  bool _loading = true;
  bool _saving = false;
  bool _sending = false;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _group = Get.arguments as GroupChatModel;
    _loadData();
  }

  @override
  void dispose() {
    _shiftStartCtrl.dispose();
    _shiftEndCtrl.dispose();
    _generalCtrl.dispose();
    for (final c in _taskCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    _jobPost = await _jobSvc.getJobPostById(_group.jobId);
    if (_jobPost != null) {
      final start = _startOfDay(_jobPost!.startDate);
      final end = _jobPost!.endDate != null 
          ? _startOfDay(_jobPost!.endDate!) 
          : start.add(const Duration(days: 365));
      final current = _startOfDay(_selectedDate);
      
      if (current.isBefore(start)) {
        _selectedDate = start;
      } else if (current.isAfter(end)) {
        _selectedDate = end;
      }
    }

    final members =
        await _groupChatSvc.getGroupMembers(_group.memberIds);
    final schedule =
        await _service.getByDate(_group.groupId, _dateStr);

    for (final m in members) {
      _taskCtrls.putIfAbsent(m.id, () => TextEditingController());
    }

    if (schedule != null) {
      _shiftStartCtrl.text = schedule.shiftStart;
      _shiftEndCtrl.text = schedule.shiftEnd;
      _generalCtrl.text = schedule.generalContent;
      final Map<String, List<String>> userTasksMap = {};
      for (final task in schedule.tasks) {
        if (task.content.trim().isNotEmpty) {
          userTasksMap.putIfAbsent(task.userId, () => []).add(task.content.trim());
        }
      }
      for (final entry in userTasksMap.entries) {
        _taskCtrls[entry.key]?.text = entry.value.join('\n---\n');
      }
    } else if (_jobPost != null) {
      final startT = (_jobPost!.startTime != null && _jobPost!.startTime!.isNotEmpty) 
          ? _jobPost!.startTime! 
          : '08:00';
      _shiftStartCtrl.text = startT;
      
      if (_jobPost!.workHoursPerDay != null) {
        final parts = startT.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]) ?? 8;
          final m = int.tryParse(parts[1]) ?? 0;
          final totalMinutes = h * 60 + m + (_jobPost!.workHoursPerDay! * 60).toInt();
          final endH = (totalMinutes ~/ 60) % 24;
          final endM = totalMinutes % 60;
          _shiftEndCtrl.text = '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';
        }
      } else {
        _shiftEndCtrl.text = '17:00';
      }
    }

    if (mounted) {
      setState(() {
        _members = members;
        _existing = schedule;
        _loading = false;
      });
    }
  }

  Future<void> _onDateChanged(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _loading = true;
      // Reset form
      if (_jobPost != null) {
        final startT = (_jobPost!.startTime != null && _jobPost!.startTime!.isNotEmpty) 
            ? _jobPost!.startTime! 
            : '08:00';
        _shiftStartCtrl.text = startT;
        
        if (_jobPost!.workHoursPerDay != null) {
          final parts = startT.split(':');
          if (parts.length == 2) {
            final h = int.tryParse(parts[0]) ?? 8;
            final m = int.tryParse(parts[1]) ?? 0;
            final totalMinutes = h * 60 + m + (_jobPost!.workHoursPerDay! * 60).toInt();
            final endH = (totalMinutes ~/ 60) % 24;
            final endM = totalMinutes % 60;
            _shiftEndCtrl.text = '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';
          }
        } else {
          _shiftEndCtrl.text = '17:00';
        }
      } else {
        _shiftStartCtrl.text = '08:00';
        _shiftEndCtrl.text = '17:00';
      }
      _generalCtrl.clear();
      for (final c in _taskCtrls.values) {
        c.clear();
      }
    });

    final schedule =
        await _service.getByDate(_group.groupId, DateFormat('yyyy-MM-dd').format(date));

    if (schedule != null) {
      _shiftStartCtrl.text = schedule.shiftStart;
      _shiftEndCtrl.text = schedule.shiftEnd;
      _generalCtrl.text = schedule.generalContent;
      final Map<String, List<String>> userTasksMap = {};
      for (final task in schedule.tasks) {
        if (task.content.trim().isNotEmpty) {
          userTasksMap.putIfAbsent(task.userId, () => []).add(task.content.trim());
        }
      }
      for (final entry in userTasksMap.entries) {
        _taskCtrls[entry.key]?.text = entry.value.join('\n---\n');
      }
    }

    if (mounted) setState(() { _existing = schedule; _loading = false; });
  }

  List<UserModel> get _employeeMembers {
    final all = _members ?? [];
    return all.where((m) => m.id != _group.employerId).toList();
  }

  WorkScheduleModel _buildScheduleModel() {
    final members = _members ?? [];
    final tasks = <WorkTask>[];
    for (final m in members) {
      final currentText = _taskCtrls[m.id]?.text.trim() ?? '';
      final existingUserTasks = _existing?.tasks.where((t) => t.userId == m.id).toList() ?? [];
      final existingText = existingUserTasks.map((t) => t.content.trim()).where((s) => s.isNotEmpty).join('\n---\n');
      
      if (currentText == existingText) {
        tasks.addAll(existingUserTasks);
      } else {
        tasks.add(WorkTask(
          taskId: DateTime.now().microsecondsSinceEpoch.toString() + m.id,
          userId: m.id,
          userName: '${m.firstName} ${m.lastName}'.trim(),
          content: currentText,
        ));
      }
    }

    return WorkScheduleModel(
      scheduleId: _existing?.scheduleId ?? '',
      groupId: _group.groupId,
      jobId: _group.jobId,
      jobTitle: _group.jobTitle,
      employerId: _group.employerId,
      date: _dateStr,
      shiftStart: _shiftStartCtrl.text,
      shiftEnd: _shiftEndCtrl.text,
      generalContent: _generalCtrl.text.trim(),
      tasks: tasks,
      createdAt: _existing?.createdAt ?? DateTime.now(),
    );
  }

  List<Map<String, String>> _memberTaskPayload() {
    return (_members ?? [])
        .where((m) => m.id != _group.employerId)
        .map(
          (m) => {
            'userId': m.id,
            'name': '${m.firstName} ${m.lastName}'.trim(),
            'content': _taskCtrls[m.id]?.text.trim() ?? '',
          },
        )
        .toList();
  }

  Future<bool> _persistSchedule() async {
    final id = await _service.saveSchedule(_buildScheduleModel());
    final s = _buildScheduleModel();
    setState(() => _existing = WorkScheduleModel(
          scheduleId: id,
          groupId: s.groupId,
          jobId: s.jobId,
          jobTitle: s.jobTitle,
          employerId: s.employerId,
          date: s.date,
          shiftStart: s.shiftStart,
          shiftEnd: s.shiftEnd,
          generalContent: s.generalContent,
          tasks: s.tasks,
          createdAt: s.createdAt,
        ));
    return true;
  }

  bool _validateBeforeSave() {
    final today = _startOfDay(DateTime.now());
    final current = _startOfDay(_selectedDate);
    if (current.isBefore(today)) {
      Get.snackbar('Lỗi', 'Không thể phân công cho ngày trong quá khứ',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      return false;
    }

    if (_jobPost != null && _jobPost!.workHoursPerDay != null) {
      final sParts = _shiftStartCtrl.text.split(':');
      final eParts = _shiftEndCtrl.text.split(':');
      if (sParts.length == 2 && eParts.length == 2) {
        final startMin = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
        var endMin = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
        if (endMin <= startMin) endMin += 24 * 60;
        final diffHours = (endMin - startMin) / 60.0;
        if (diffHours < 10) {
          Get.snackbar('Lỗi', 'Ca làm việc phải đủ 10 tiếng',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red,
              colorText: Colors.white);
          return false;
        }
      }
    }

    if ((_members ?? []).isEmpty) {
      Get.snackbar('Lỗi', 'Không có thành viên',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validateBeforeSave()) return;

    setState(() => _saving = true);
    try {
      await _persistSchedule();
      Get.snackbar('Đã lưu', 'Đã lưu phân công (chưa gửi cho nhân viên)',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể lưu: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendToEmployees() async {
    if (!_validateBeforeSave()) return;

    final employees = _employeeMembers;
    if (employees.isEmpty) {
      Get.snackbar('Lỗi', 'Không có nhân viên trong nhóm',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Gửi phân công?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Gửi phân công ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate)} '
          'cho ${employees.length} nhân viên qua thông báo? '
          'Họ sẽ nhấn thông báo để xem phân công.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.employerPrimary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gửi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      await _persistSchedule();

      final general = _generalCtrl.text.trim();
      final tasks = _memberTaskPayload();

      final sent = await _groupChatSvc.notifyWorkAssignmentToMembers(
        groupId: _group.groupId,
        jobTitle: _group.jobTitle,
        date: _dateStr,
        shiftStart: _shiftStartCtrl.text,
        shiftEnd: _shiftEndCtrl.text,
        generalContent: general,
        memberTasks: tasks,
        employerId: _group.employerId,
      );

      Get.snackbar(
        'Đã gửi',
        'Đã gửi thông báo phân công cho $sent nhân viên',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar('Lỗi', 'Không gửi được: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.employerPrimary,
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.employerGradient)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: Get.back,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Phân công công việc',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(_group.jobTitle,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
            tooltip: 'Danh sách phân công',
            onPressed: _loading
                ? null
                : () async {
                    await Get.to(() => AssignedTasksListScreen(
                          group: _group,
                          date: _selectedDate,
                        ));
                    if (mounted) {
                      await _onDateChanged(_selectedDate);
                    }
                  },
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, color: Colors.white),
            onPressed: _saving ? null : _save,
            tooltip: 'Lưu lịch',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date picker
                  _buildDatePicker(),
                  const SizedBox(height: 16),
                  // Shift times
                  _buildShiftTimes(),
                  const SizedBox(height: 16),
                  // Nội dung chung
                  _buildGeneralContent(),
                  const SizedBox(height: 16),
                  // Phân công công việc
                  _buildTaskAssignment(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
      bottomNavigationBar: _loading ? null : _buildBottomActions(),
    );
  }

  Widget _buildBottomActions() {
    const barHeight = 56.0;
    const radius = BorderRadius.all(Radius.circular(14));
    final busy = _saving || _sending;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: barHeight,
                  child: OutlinedButton(
                    onPressed: busy ? null : _save,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.employerPrimary,
                      side: BorderSide(
                        color: AppColors.employerPrimary.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      shape: const RoundedRectangleBorder(borderRadius: radius),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const _BottomActionLabel(
                            icon: Icons.save_rounded,
                            label: 'Lưu nháp',
                            color: AppColors.employerPrimary,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: barHeight,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: AppColors.employerGradient,
                      borderRadius: radius,
                    ),
                    child: ElevatedButton(
                      onPressed: busy ? null : _sendToEmployees,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: radius),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const _BottomActionLabel(
                              icon: Icons.send_rounded,
                              label: 'Gửi nhân viên',
                              color: Colors.white,
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

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final start = _jobPost != null ? _startOfDay(_jobPost!.startDate) : DateTime.now().subtract(const Duration(days: 30));
        final end = _jobPost?.endDate != null ? _startOfDay(_jobPost!.endDate!) : start.add(const Duration(days: 365));
        
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: start,
          lastDate: end,
          builder: (ctx, child) => Theme(
            data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                    primary: AppColors.employerPrimary)),
            child: child!,
          ),
        );
        if (picked != null) await _onDateChanged(picked);
      },
      child: _Card(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  gradient: AppColors.employerGradient,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.calendar_today,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ngày làm việc',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  DateFormat('EEEE, dd/MM/yyyy', 'vi')
                      .format(_selectedDate),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.edit_calendar_rounded,
                color: AppColors.employerPrimary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftTimes() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
              icon: Icons.access_time_rounded, title: 'Giờ làm việc'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimePicker(
                  label: 'Bắt đầu',
                  controller: _shiftStartCtrl,
                  context: context,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.grey, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePicker(
                  label: 'Kết thúc',
                  controller: _shiftEndCtrl,
                  context: context,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralContent() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
              icon: Icons.description_rounded, title: 'Nội dung & Yêu cầu chung'),
          const SizedBox(height: 12),
          TextField(
            controller: _generalCtrl,
            maxLines: 5,
            decoration: InputDecoration(
              hintText:
                  'Nhập nội dung công việc, yêu cầu, lưu ý chung cho toàn nhóm...',
              hintStyle:
                  TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8F9FC),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskAssignment() {
    final members = _employeeMembers;
    if (members.isEmpty) {
      return const _Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Không có nhân viên trong nhóm',
                style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
              icon: Icons.assignment_ind_rounded,
              title: 'Phân công công việc'),
          const SizedBox(height: 4),
          Text('Giao nhiệm vụ cụ thể cho từng nhân viên',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          ...members.asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            final name = '${m.firstName} ${m.lastName}'.trim();
            return Column(
              children: [
                if (i > 0) Divider(height: 24, color: Colors.grey.shade100),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppColors.employerPrimary.withOpacity(0.12),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.employerPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _taskCtrls[m.id],
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Công việc được giao cho $name...',
                              hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _BottomActionLabel extends StatelessWidget {
  const _BottomActionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.employerPrimary, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    );
  }
}

class _TimePicker extends StatelessWidget {
  const _TimePicker({
    required this.label,
    required this.controller,
    required this.context,
  });
  final String label;
  final TextEditingController controller;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
      onTap: () async {
        final parsed = controller.text.split(':');
        final initial = parsed.length == 2
            ? TimeOfDay(
                hour: int.tryParse(parsed[0]) ?? 8,
                minute: int.tryParse(parsed[1]) ?? 0)
            : TimeOfDay.now();
        final picked = await showTimePicker(
          context: context,
          initialTime: initial,
          builder: (c, child) => Theme(
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
            labelText: label,
            prefixIcon: const Icon(Icons.access_time, size: 18),
            filled: true,
            fillColor: const Color(0xFFF8F9FC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
