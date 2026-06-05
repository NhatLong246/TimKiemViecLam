import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../data/services/alarm_manager_service.dart';
import '../../data/models/personal_alarm_model.dart';

class AlarmSetupScreen extends StatefulWidget {
  const AlarmSetupScreen({super.key});

  @override
  State<AlarmSetupScreen> createState() => _AlarmSetupScreenState();
}

class _AlarmSetupScreenState extends State<AlarmSetupScreen> {
  bool _isSyncing = false;
  List<PersonalAlarmModel> _personalAlarms = [];
  bool _isLoadingAlarms = true;

  @override
  void initState() {
    super.initState();
    _loadPersonalAlarms();
  }

  Future<void> _loadPersonalAlarms() async {
    final alarms = await AlarmManagerService.instance.getPersonalAlarms();
    if (mounted) {
      setState(() {
        _personalAlarms = alarms;
        _isLoadingAlarms = false;
      });
    }
  }

  Future<void> _addPersonalAlarm() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null || !mounted) return;

    final TextEditingController titleController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nhập tiêu đề báo thức'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(
              hintText: 'Ví dụ: Dậy chuẩn bị đi làm',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && titleController.text.trim().isNotEmpty) {
      final alarm = PersonalAlarmModel(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: titleController.text.trim(),
        time: pickedTime,
        isActive: true,
      );
      await AlarmManagerService.instance.addPersonalAlarm(alarm);
      _loadPersonalAlarms();
    }
  }

  Future<void> _syncAlarms() async {
    setState(() => _isSyncing = true);
    try {
      await AlarmManagerService.instance.syncAutomaticAlarms();
      Get.snackbar(
        'Thành công',
        'Đã đồng bộ báo thức cho các ca làm việc sắp tới!',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể đồng bộ: $e',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _testAlarm() async {
    final testTime = DateTime.now().add(const Duration(seconds: 15));
    await AlarmManagerService.instance.scheduleAlarm(
      id: 9999,
      title: 'Báo động Test!',
      body: 'Đây là báo thức test (15s).',
      scheduledDate: testTime,
      payloadData: {
        'title': 'BÁO ĐỘNG ĐỎ TEST',
        'body': 'Báo thức hoạt động tốt!',
      },
    );
    Get.snackbar(
      'Đã lên lịch',
      'Báo thức sẽ reo sau 15 giây nữa. Hãy thoát ra ngoài màn hình chính để test Full-screen Intent nhé!',
      backgroundColor: Colors.blue.shade100,
      colorText: Colors.blue.shade900,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo thức khẩn cấp'),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.alarm_on_rounded, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Hệ thống Nhắc nhở & Cảnh báo Khẩn',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'App sẽ tự động rung chuông báo động (như báo thức) trước 30 phút khi bạn có ca làm việc sắp diễn ra. Bạn cũng có thể thiết lập thủ công tại đây.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            icon: _isSyncing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync),
            label: const Text('Đồng bộ Ca làm việc Tự động'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              textStyle: const TextStyle(fontSize: 18),
            ),
            onPressed: _isSyncing ? null : _syncAlarms,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.access_alarm),
            label: const Text('Test Báo thức (sau 15 giây)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              textStyle: const TextStyle(fontSize: 18),
            ),
            onPressed: _testAlarm,
          ),
          const SizedBox(height: 30),
          const Divider(),
          const Divider(),
          ListTile(
            title: const Text('Danh sách Báo thức cá nhân', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            trailing: IconButton(
              icon: const Icon(Icons.add_alert, color: Colors.blue),
              onPressed: _addPersonalAlarm,
            ),
          ),
          if (_isLoadingAlarms)
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ))
          else if (_personalAlarms.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Chưa có báo thức cá nhân nào. Nhấn biểu tượng 🔔 để thêm.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center,),
            )
          else
            ..._personalAlarms.map((alarm) => Dismissible(
              key: Key(alarm.id.toString()),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) async {
                await AlarmManagerService.instance.deletePersonalAlarm(alarm.id);
                _loadPersonalAlarms();
              },
              child: Card(
                elevation: 0.5,
                child: ListTile(
                  title: Text(
                    '${alarm.time.hour.toString().padLeft(2, '0')}:${alarm.time.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(alarm.title),
                  trailing: Switch(
                    value: alarm.isActive,
                    activeColor: Colors.blue,
                    onChanged: (val) async {
                      await AlarmManagerService.instance.togglePersonalAlarm(alarm.id, val);
                      _loadPersonalAlarms();
                    },
                  ),
                ),
              ),
            )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
