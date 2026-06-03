import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../data/services/alarm_manager_service.dart';

class AlarmSetupScreen extends StatefulWidget {
  const AlarmSetupScreen({super.key});

  @override
  State<AlarmSetupScreen> createState() => _AlarmSetupScreenState();
}

class _AlarmSetupScreenState extends State<AlarmSetupScreen> {
  bool _isSyncing = false;

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
          const ListTile(
            title: Text('Thêm báo thức cá nhân', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Tính năng sắp ra mắt...'),
            trailing: Icon(Icons.add_alert),
          )
        ],
      ),
    );
  }
}
