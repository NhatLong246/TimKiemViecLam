import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../data/services/alarm_manager_service.dart';
import '../../data/models/personal_alarm_model.dart';
import 'package:jbh_ringtone/jbh_ringtone.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmSetupScreen extends StatefulWidget {
  const AlarmSetupScreen({super.key});

  @override
  State<AlarmSetupScreen> createState() => _AlarmSetupScreenState();
}

class _AlarmSetupScreenState extends State<AlarmSetupScreen> {
  bool _isSyncing = false;
  List<PersonalAlarmModel> _personalAlarms = [];
  bool _isLoadingAlarms = true;
  String _selectedRingtoneTitle = 'Mặc định';
  String? _selectedRingtoneUri;

  @override
  void initState() {
    super.initState();
    _loadPersonalAlarms();
    _loadCustomRingtone();
  }

  Future<void> _loadCustomRingtone() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString('custom_alarm_ringtone_uri');
    final title = prefs.getString('custom_alarm_ringtone_title');
    if (mounted) {
      setState(() {
        _selectedRingtoneUri = uri;
        _selectedRingtoneTitle = title ?? 'Mặc định';
      });
    }
  }

  Future<void> _pickRingtone() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final ringtones = await JbhRingtone().getAlarmRingtones();
      if (!mounted) return;
      Navigator.pop(context); // close loading

      if (ringtones.isEmpty) {
        Get.snackbar('Thông báo', 'Không tìm thấy nhạc chuông trên thiết bị.');
        return;
      }

      JbhRingtoneModel? tempSelected;
      String? playingUri;
      
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                expand: false,
                builder: (_, controller) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Chọn nhạc chuông', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () {
                                JbhRingtone().stopRingtone();
                                Navigator.pop(context);
                              },
                              child: const Text('Đóng'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Mặc định (Hệ thống)'),
                        trailing: _selectedRingtoneUri == null ? const Icon(Icons.check, color: Colors.blue) : null,
                        onTap: () async {
                          JbhRingtone().stopRingtone();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('custom_alarm_ringtone_uri');
                          await prefs.remove('custom_alarm_ringtone_title');
                          setState(() {
                            _selectedRingtoneUri = null;
                            _selectedRingtoneTitle = 'Mặc định';
                          });
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          controller: controller,
                          itemCount: ringtones.length,
                          itemBuilder: (context, index) {
                            final r = ringtones[index];
                            final isSelected = tempSelected?.uri == r.uri || (_selectedRingtoneUri == r.uri && tempSelected == null);
                            
                            return ListTile(
                              leading: IconButton(
                                icon: Icon(
                                  playingUri == r.uri ? Icons.stop_circle : Icons.play_circle_outline,
                                  color: playingUri == r.uri ? Colors.red : Colors.blue,
                                  size: 32,
                                ),
                                onPressed: () {
                                  if (playingUri == r.uri) {
                                    JbhRingtone().stopRingtone();
                                    setSheetState(() => playingUri = null);
                                  } else {
                                    JbhRingtone().playRingtone(r.uri);
                                    setSheetState(() => playingUri = r.uri);
                                  }
                                },
                              ),
                              title: Text(r.title),
                              trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                              onTap: () {
                                setSheetState(() {
                                  tempSelected = r;
                                  playingUri = r.uri;
                                });
                                JbhRingtone().playRingtone(r.uri);
                              },
                              onLongPress: () async {
                                JbhRingtone().stopRingtone();
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('custom_alarm_ringtone_uri', r.uri);
                                await prefs.setString('custom_alarm_ringtone_title', r.title);
                                setState(() {
                                  _selectedRingtoneUri = r.uri;
                                  _selectedRingtoneTitle = r.title;
                                });
                                if (mounted) Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            JbhRingtone().stopRingtone();
                            if (tempSelected != null) {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('custom_alarm_ringtone_uri', tempSelected!.uri);
                              await prefs.setString('custom_alarm_ringtone_title', tempSelected!.title);
                              setState(() {
                                _selectedRingtoneUri = tempSelected!.uri;
                                _selectedRingtoneTitle = tempSelected!.title;
                              });
                            }
                            if (mounted) Navigator.pop(context);
                          },
                          child: const Text('Lưu lựa chọn'),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ).then((_) {
        JbhRingtone().stopRingtone();
      });
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Get.snackbar('Lỗi', 'Không thể tải nhạc chuông: $e');
    }
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
          const SizedBox(height: 24),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.music_note, color: Colors.blue),
              title: const Text('Nhạc chuông báo thức', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_selectedRingtoneTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickRingtone,
            ),
          ),
          const SizedBox(height: 16),
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
