import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/work_schedule_model.dart';
import '../../data/services/group_chat_service.dart';
import '../../data/services/work_schedule_service.dart';

class AssignedTasksListScreen extends StatefulWidget {
  const AssignedTasksListScreen({
    super.key,
    required this.group,
    required this.date,
  });

  final GroupChatModel group;
  final DateTime date;

  @override
  State<AssignedTasksListScreen> createState() =>
      _AssignedTasksListScreenState();
}

class _AssignedTasksListScreenState extends State<AssignedTasksListScreen> {
  final _service = WorkScheduleService();
  final _groupChatSvc = GroupChatService();

  bool _loading = true;
  WorkScheduleModel? _schedule;
  List<UserModel> _members = [];

  String get _dateStr => DateFormat('yyyy-MM-dd').format(widget.date);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final futures = await Future.wait([
      _groupChatSvc.getGroupMembers(widget.group.memberIds),
      _service.getByDate(widget.group.groupId, _dateStr),
    ]);
    
    if (mounted) {
      setState(() {
        _members = futures[0] as List<UserModel>;
        _schedule = futures[1] as WorkScheduleModel?;
        _loading = false;
      });
    }
  }

  Future<void> _updateSchedule(WorkScheduleModel newSchedule) async {
    setState(() => _loading = true);
    try {
      final id = await _service.saveSchedule(newSchedule);
      final s = WorkScheduleModel(
        scheduleId: id,
        groupId: newSchedule.groupId,
        jobId: newSchedule.jobId,
        jobTitle: newSchedule.jobTitle,
        employerId: newSchedule.employerId,
        date: newSchedule.date,
        shiftStart: newSchedule.shiftStart,
        shiftEnd: newSchedule.shiftEnd,
        generalContent: newSchedule.generalContent,
        tasks: newSchedule.tasks,
        createdAt: newSchedule.createdAt,
      );
      if (mounted) {
        setState(() {
          _schedule = s;
        });
        Get.snackbar('Thành công', 'Đã cập nhật phân công',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể lưu: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _deleteTask(WorkTask task) {
    if (_schedule == null) return;
    
    Get.defaultDialog(
      title: 'Xóa phân công',
      middleText: 'Bạn có chắc muốn xóa phân công của ${task.userName}?',
      textCancel: 'Hủy',
      textConfirm: 'Xóa',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        Get.back();
        final newTasks = _schedule!.tasks.where((t) => t.taskId != task.taskId).toList();
        final newSchedule = WorkScheduleModel(
          scheduleId: _schedule!.scheduleId,
          groupId: _schedule!.groupId,
          jobId: _schedule!.jobId,
          jobTitle: _schedule!.jobTitle,
          employerId: _schedule!.employerId,
          date: _schedule!.date,
          shiftStart: _schedule!.shiftStart,
          shiftEnd: _schedule!.shiftEnd,
          generalContent: _schedule!.generalContent,
          tasks: newTasks,
          createdAt: _schedule!.createdAt,
        );
        _updateSchedule(newSchedule);
      },
    );
  }

  void _editTask(WorkTask task) {
    final ctrl = TextEditingController(text: task.content);
    Get.defaultDialog(
      title: 'Sửa phân công',
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Nhập nội dung công việc...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textCancel: 'Hủy',
      textConfirm: 'Lưu',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.employerPrimary,
      onConfirm: () {
        Get.back();
        if (_schedule == null) return;
        final newTasks = _schedule!.tasks.map((t) {
          if (t.taskId == task.taskId) {
            return WorkTask(
              taskId: t.taskId,
              userId: t.userId,
              userName: t.userName,
              content: ctrl.text.trim(),
            );
          }
          return t;
        }).toList();
        
        final newSchedule = WorkScheduleModel(
          scheduleId: _schedule!.scheduleId,
          groupId: _schedule!.groupId,
          jobId: _schedule!.jobId,
          jobTitle: _schedule!.jobTitle,
          employerId: _schedule!.employerId,
          date: _schedule!.date,
          shiftStart: _schedule!.shiftStart,
          shiftEnd: _schedule!.shiftEnd,
          generalContent: _schedule!.generalContent,
          tasks: newTasks,
          createdAt: _schedule!.createdAt,
        );
        _updateSchedule(newSchedule);
      },
    );
  }

  void _addTask() {
    if (_schedule == null) {
      Get.snackbar('Lỗi', 'Chưa có thông tin ca làm việc. Vui lòng lưu nháp ở màn hình trước để tạo ca.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    
    final employeeMembers = _members.where((m) => m.id != widget.group.employerId).toList();

    if (employeeMembers.isEmpty) {
      Get.snackbar('Thông báo', 'Không có nhân viên trong nhóm.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    UserModel? selectedUser = employeeMembers.first;
    final ctrl = TextEditingController();

    Get.defaultDialog(
      title: 'Thêm phân công mới',
      content: StatefulBuilder(
        builder: (context, setStateBuilder) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserModel>(
                value: selectedUser,
                isExpanded: true,
                items: employeeMembers.map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('${m.firstName} ${m.lastName}'.trim()),
                  );
                }).toList(),
                onChanged: (val) {
                  setStateBuilder(() => selectedUser = val);
                },
                decoration: InputDecoration(
                  labelText: 'Chọn nhân viên',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Nhập nội dung công việc...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        }
      ),
      textCancel: 'Hủy',
      textConfirm: 'Thêm',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.employerPrimary,
      onConfirm: () {
        Get.back();
        if (selectedUser == null || ctrl.text.trim().isEmpty) {
          Get.snackbar('Lỗi', 'Vui lòng chọn nhân viên và nhập nội dung', snackPosition: SnackPosition.BOTTOM);
          return;
        }
        
        final name = '${selectedUser!.firstName} ${selectedUser!.lastName}'.trim();
        final newTask = WorkTask(
          taskId: DateTime.now().microsecondsSinceEpoch.toString(),
          userId: selectedUser!.id,
          userName: name,
          content: ctrl.text.trim(),
        );

        var tasks = List<WorkTask>.from(_schedule!.tasks);
        tasks.add(newTask);
        
        final newSchedule = WorkScheduleModel(
          scheduleId: _schedule!.scheduleId,
          groupId: _schedule!.groupId,
          jobId: _schedule!.jobId,
          jobTitle: _schedule!.jobTitle,
          employerId: _schedule!.employerId,
          date: _schedule!.date,
          shiftStart: _schedule!.shiftStart,
          shiftEnd: _schedule!.shiftEnd,
          generalContent: _schedule!.generalContent,
          tasks: tasks,
          createdAt: _schedule!.createdAt,
        );
        _updateSchedule(newSchedule);
      },
    );
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
            const Text('Danh sách phân công',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(DateFormat('dd/MM/yyyy').format(widget.date),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: _loading 
          ? null 
          : FloatingActionButton(
              onPressed: _addTask,
              backgroundColor: AppColors.employerPrimary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildContent() {
    if (_schedule == null || _schedule!.tasks.where((t) => t.content.trim().isNotEmpty).isEmpty) {
      return const Center(
        child: Text('Chưa có phân công nào cho ngày này.', style: TextStyle(color: Colors.grey)),
      );
    }

    final activeTasks = _schedule!.tasks.where((t) => t.content.trim().isNotEmpty).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeTasks.length,
      itemBuilder: (context, index) {
        final task = activeTasks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.employerPrimary.withValues(alpha: 0.12),
                      child: Text(
                        task.userName.isNotEmpty ? task.userName[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.employerPrimary, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.userName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _editTask(task),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _deleteTask(task),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  task.content,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
