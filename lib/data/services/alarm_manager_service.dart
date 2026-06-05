import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/job_post_model.dart';
import '../../utils/push_navigation_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/personal_alarm_model.dart';
import 'package:flutter/material.dart';
import 'push_notification_service.dart';

class AlarmManagerService {
  static final AlarmManagerService instance = AlarmManagerService._();
  AlarmManagerService._();

  FlutterLocalNotificationsPlugin get _local => PushNotificationService.instance.localPlugin;
  late final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required Map<String, dynamic> payloadData,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    final androidDetails = AndroidNotificationDetails(
      'alarm_channel_v2',
      'Báo thức & Nhắc nhở',
      channelDescription: 'Báo động đỏ khi có ca làm việc sắp diễn ra',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    );

    final details = NotificationDetails(android: androidDetails);
    
    // Add type 'alarm' to payload
    payloadData['type'] = 'alarm';

    try {
      await _local.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(payloadData),
    );
    } catch (e) {
      debugPrint('Exact alarm failed: $e, falling back to inexact');
      await _local.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode(payloadData),
      );
    }
  }

  Future<void> testNotification() async {
    final androidDetails = AndroidNotificationDetails(
      'test_channel_v1',
      'Test Thông báo',
      importance: Importance.max,
      priority: Priority.max,
    );
    await _local.show(
      99999,
      '🔔 Đã gọi được thông báo!',
      'Hệ thống thông báo hoạt động bình thường.',
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelAlarm(int id) async {
    await _local.cancel(id);
  }

  /// Tự động quét các công việc sắp tới (đã được nhận) và lên lịch báo thức.
  Future<void> syncAutomaticAlarms() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await _db.collection('users').doc(uid).get();
    if ((userDoc.data()?['role'] ?? 'candidate') != 'candidate') return;

    final appsSnap = await _db.collection('applications')
        .where('candidateId', isEqualTo: uid)
        .get();

    for (final doc in appsSnap.docs) {
      final appData = doc.data();
      final jobId = (appData['jobId'] ?? '').toString();
      final appStatus = (appData['status'] ?? '').toString();
      
      if (jobId.isEmpty) continue;

      final jobDoc = await _db.collection('jobPosts').doc(jobId).get();
      if (!jobDoc.exists) continue;

      final jobData = jobDoc.data()!;
      jobData['jobId'] = jobId;
      final job = JobPostModel.fromMap(jobData);

      if (job.startTime == null) continue;

      final startParts = job.startTime!.split(':');
      if (startParts.length != 2) continue;

      // Tính toán giờ làm việc mỗi ngày
      final startHours = int.parse(startParts[0]);
      final startMins = int.parse(startParts[1]);
      final workHours = job.workHoursPerDay ?? 8.0;
      
      final endTotalMins = (startHours * 60 + startMins + (workHours * 60).toInt());
      final endHours = (endTotalMins ~/ 60) % 24;
      final endMins = endTotalMins % 60;

      DateTime currentDay = DateTime(job.startDate.year, job.startDate.month, job.startDate.day);
      final endDay = job.endDate != null ? DateTime(job.endDate!.year, job.endDate!.month, job.endDate!.day) : currentDay;

      // Nếu công việc đã kết thúc/hủy, hoặc ứng dụng không còn được chấp nhận, hủy toàn bộ báo thức
      if (appStatus != 'accepted' || 
          job.status == 'completed' || 
          job.status == 'cancelled' || 
          job.status == 'closed' || 
          job.status == 'deleted') {
        DateTime cancelDay = currentDay;
        while (cancelDay.compareTo(endDay.add(const Duration(days: 1))) < 0) {
          final startAlarmTime = DateTime(cancelDay.year, cancelDay.month, cancelDay.day, startHours, startMins);
          await cancelAlarm((jobId + startAlarmTime.toIso8601String() + "_start").hashCode);

          final endAlarmTime = DateTime(cancelDay.year, cancelDay.month, cancelDay.day, endHours, endMins);
          final finalEndAlarmTime = endAlarmTime.isBefore(startAlarmTime) 
              ? endAlarmTime.add(const Duration(days: 1)) 
              : endAlarmTime;
          await cancelAlarm((jobId + finalEndAlarmTime.toIso8601String() + "_end").hashCode);

          cancelDay = cancelDay.add(const Duration(days: 1));
        }
        continue;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Bỏ qua nếu công việc đã hoàn toàn nằm trong quá khứ
      if (endDay.isBefore(today.subtract(const Duration(days: 1)))) continue;

      // Fast-forward currentDay tới hôm nay nếu nó nằm quá xa trong quá khứ (để tránh lặp dư thừa)
      if (currentDay.isBefore(today)) {
        currentDay = today;
      }

      while (currentDay.compareTo(endDay.add(const Duration(days: 1))) < 0) {
        // Báo thức ĐẦU CA (đúng giờ bắt đầu)
        final startAlarmTime = DateTime(currentDay.year, currentDay.month, currentDay.day, startHours, startMins);
        if (startAlarmTime.isAfter(DateTime.now())) {
          final alarmId = (jobId + startAlarmTime.toIso8601String() + "_start").hashCode;
          await scheduleAlarm(
            id: alarmId,
            title: '⏰ Đến giờ làm việc!',
            body: 'Ca làm việc "${job.title}" đã bắt đầu. Hãy vào ứng dụng chụp ảnh điểm danh ĐẦU CA ngay nhé!',
            scheduledDate: startAlarmTime,
            payloadData: {
              'jobId': jobId,
            },
          );
        }

        // Báo thức CUỐI CA (đúng giờ kết thúc)
        final endAlarmTime = DateTime(currentDay.year, currentDay.month, currentDay.day, endHours, endMins);
        // Chú ý ca qua đêm: nếu giờ kết thúc < giờ bắt đầu thì cộng thêm 1 ngày
        final finalEndAlarmTime = endAlarmTime.isBefore(startAlarmTime) 
            ? endAlarmTime.add(const Duration(days: 1)) 
            : endAlarmTime;
            
        if (finalEndAlarmTime.isAfter(DateTime.now())) {
          final alarmId = (jobId + finalEndAlarmTime.toIso8601String() + "_end").hashCode;
          await scheduleAlarm(
            id: alarmId,
            title: '⏰ Đã hết ca làm việc!',
            body: 'Ca làm "${job.title}" vừa kết thúc. Hãy vào ứng dụng chụp ảnh điểm danh CUỐI CA để được ghi nhận công!',
            scheduledDate: finalEndAlarmTime,
            payloadData: {
              'jobId': jobId,
            },
          );
        }

        currentDay = currentDay.add(const Duration(days: 1));
      }
    }
  }

  // --- PERSONAL ALARM IMPLEMENTATION ---

  Future<List<PersonalAlarmModel>> getPersonalAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final dataList = prefs.getStringList('personal_alarms') ?? [];
    return dataList.map((e) => PersonalAlarmModel.fromJson(e)).toList();
  }

  Future<void> _saveAllPersonalAlarms(List<PersonalAlarmModel> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final dataList = alarms.map((e) => e.toJson()).toList();
    await prefs.setStringList('personal_alarms', dataList);
  }

  Future<void> addPersonalAlarm(PersonalAlarmModel alarm) async {
    final alarms = await getPersonalAlarms();
    alarms.add(alarm);
    await _saveAllPersonalAlarms(alarms);
    if (alarm.isActive) {
      await _schedulePersonalAlarm(alarm);
    }
  }

  Future<void> togglePersonalAlarm(int id, bool isActive) async {
    final alarms = await getPersonalAlarms();
    final index = alarms.indexWhere((e) => e.id == id);
    if (index != -1) {
      final updated = alarms[index].copyWith(isActive: isActive);
      alarms[index] = updated;
      await _saveAllPersonalAlarms(alarms);
      if (isActive) {
        await _schedulePersonalAlarm(updated);
      } else {
        await cancelAlarm(id);
      }
    }
  }

  Future<void> deletePersonalAlarm(int id) async {
    final alarms = await getPersonalAlarms();
    alarms.removeWhere((e) => e.id == id);
    await _saveAllPersonalAlarms(alarms);
    await cancelAlarm(id);
  }

  Future<void> _schedulePersonalAlarm(PersonalAlarmModel alarm) async {
    final now = DateTime.now();
    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.time.hour,
      alarm.time.minute,
    );

    // Nếu giờ đã qua trong ngày, lên lịch vào ngày mai
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await scheduleAlarm(
      id: alarm.id,
      title: '⏰ Báo thức cá nhân',
      body: alarm.title,
      scheduledDate: scheduledDate,
      payloadData: {
        'isPersonal': true,
      },
    );
  }
}
