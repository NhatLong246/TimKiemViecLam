import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/job_post_model.dart';
import '../../utils/push_navigation_handler.dart';

class AlarmManagerService {
  static final AlarmManagerService instance = AlarmManagerService._();
  AlarmManagerService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required Map<String, dynamic> payloadData,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    final androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Báo thức & Nhắc nhở',
      channelDescription: 'Báo động đỏ khi có ca làm việc sắp diễn ra',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT
    );

    final details = NotificationDetails(android: androidDetails);
    
    // Add type 'alarm' to payload
    payloadData['type'] = 'alarm';

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
        .where('status', isEqualTo: 'accepted')
        .get();

    for (final doc in appsSnap.docs) {
      final jobId = (doc.data()['jobId'] ?? '').toString();
      if (jobId.isEmpty) continue;

      final jobDoc = await _db.collection('jobPosts').doc(jobId).get();
      if (!jobDoc.exists) continue;

      final jobData = jobDoc.data()!;
      jobData['jobId'] = jobId;
      final job = JobPostModel.fromMap(jobData);

      if (job.startTime == null || job.startDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
        continue;
      }

      final startParts = job.startTime!.split(':');
      if (startParts.length != 2) continue;

      // Hẹn giờ báo thức vào đầu mỗi ngày làm việc, trước 30 phút
      DateTime currentDay = DateTime(job.startDate.year, job.startDate.month, job.startDate.day, int.parse(startParts[0]), int.parse(startParts[1]));
      final endDay = job.endDate != null ? DateTime(job.endDate!.year, job.endDate!.month, job.endDate!.day) : currentDay;

      while (currentDay.compareTo(endDay.add(const Duration(days: 1))) < 0) {
        final alarmTime = currentDay.subtract(const Duration(minutes: 30));
        
        if (alarmTime.isAfter(DateTime.now())) {
          final alarmId = (jobId + currentDay.toIso8601String()).hashCode;
          await scheduleAlarm(
            id: alarmId,
            title: 'Khẩn cấp: Ca làm việc sắp bắt đầu!',
            body: 'Bạn có ca làm việc "${job.title}" lúc ${job.startTime}. Hãy chuẩn bị điểm danh ngay!',
            scheduledDate: alarmTime,
            payloadData: {
              'jobId': jobId,
            },
          );
        }
        currentDay = currentDay.add(const Duration(days: 1));
      }
    }
  }
}
