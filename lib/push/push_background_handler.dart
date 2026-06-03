import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String kPushDefaultChannelId = 'viecnow_default';
const String kPushDefaultChannelName = 'Thông báo ViecNow';
const String kCallChannelId = 'call_channel_final'; // Đồng bộ tuyệt đối với Service

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  if (kIsWeb) return;

  final data = message.data;
  final type = data['type']?.toString();

  // CHỈ xử lý thủ công cho cuộc gọi để ép hiện thông báo nổi (Heads-up)
  if (type != 'call') return;

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await plugin.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));

  // TẠO KÊNH ƯU TIÊN CAO NHẤT
  const callChannel = AndroidNotificationChannel(
    kCallChannelId,
    'Cuộc gọi đến',
    description: 'Thông báo cuộc gọi video và thoại quan trọng',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    showBadge: true,
  );

  await plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(callChannel);

  final title = data['title']?.toString() ?? 'Cuộc gọi đến';
  final body = data['body']?.toString() ?? 'Đang gọi video cho bạn...';

  await plugin.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        callChannel.id,
        callChannel.name,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        fullScreenIntent: true, // Ép hiển thị trên màn hình khóa và Heads-up
        category: AndroidNotificationCategory.call,
        ongoing: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,
        ticker: 'Có cuộc gọi đến...',
        actions: [
          const AndroidNotificationAction('decline_call', 'Từ chối', showsUserInterface: true, cancelNotification: true),
          const AndroidNotificationAction('accept_call', 'Trả lời', showsUserInterface: true),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true, 
        presentBadge: true, 
        presentSound: true, 
        categoryIdentifier: 'call_category'
      ),
    ),
    payload: jsonEncode(data),
  );
}
