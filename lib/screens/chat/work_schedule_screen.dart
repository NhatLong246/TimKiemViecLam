import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/work_schedule_model.dart';
import '../../data/services/group_chat_service.dart';
import '../../data/services/work_schedule_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WorkScheduleScreen — Lịch làm việc
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

  DateTime _selectedDate = DateTime.now();
  final _shiftStartCtrl = TextEditingController(text: '08:00');
  final _shiftEndCtrl = TextEditingController(text: '17:00');
  final _generalCtrl = TextEditingController();
  final Map<String, TextEditingController> _taskCtrls = {};

  List<UserModel>? _members;
  WorkScheduleModel? _existing;
  bool _loading = true;
  bool _saving = false;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

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
      for (final task in schedule.tasks) {
        _taskCtrls[task.userId]?.text = task.content;
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
      _shiftStartCtrl.text = '08:00';
      _shiftEndCtrl.text = '17:00';
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
      for (final task in schedule.tasks) {
        _taskCtrls[task.userId]?.text = task.content;
      }
    }

    if (mounted) setState(() { _existing = schedule; _loading = false; });
  }

  Future<void> _save() async {
    final members = _members ?? [];
    if (members.isEmpty) {
      Get.snackbar('Lỗi', 'Không có thành viên',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _saving = true);

    final tasks = members
        .map((m) => WorkTask(
              userId: m.id,
              userName: '${m.firstName} ${m.lastName}'.trim(),
              content: _taskCtrls[m.id]?.text.trim() ?? '',
            ))
        .toList();

    final schedule = WorkScheduleModel(
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

    try {
      final id = await _service.saveSchedule(schedule);
      setState(() => _existing = WorkScheduleModel(
            scheduleId: id,
            groupId: schedule.groupId,
            jobId: schedule.jobId,
            jobTitle: schedule.jobTitle,
            employerId: schedule.employerId,
            date: schedule.date,
            shiftStart: schedule.shiftStart,
            shiftEnd: schedule.shiftEnd,
            generalContent: schedule.generalContent,
            tasks: schedule.tasks,
            createdAt: schedule.createdAt,
          ));
      Get.snackbar('Đã lưu', 'Lịch làm việc đã được cập nhật',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể lưu lịch làm việc',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
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
            const Text('Lịch làm việc',
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
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        backgroundColor: AppColors.employerPrimary,
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_rounded, color: Colors.white),
        label: Text(_existing != null ? 'Cập nhật' : 'Lưu lịch',
            style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 90)),
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
    final members = _members ?? [];
    if (members.isEmpty) {
      return const _Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Không có thành viên',
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
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
