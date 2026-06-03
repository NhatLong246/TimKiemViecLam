import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String kPushDefaultChannelId = 'viecnow_default';
const String kPushDefaultChannelName = 'Thông báo ViecNow';
const String kCallChannelId = 'call_channel_v6'; // Đồng bộ với Service v6

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  if (kIsWeb) return;

  final data = message.data;
  final type = data['type']?.toString();

  // Chỉ xử lý thủ công cho cuộc gọi để ép giao diện nổi (Heads-up) như Messenger
  if (type != 'call') return;

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await plugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  const callChannel = AndroidNotificationChannel(
    kCallChannelId,
    'Cuộc gọi đến',
    description: 'Thông báo cuộc gọi video và thoại',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
  );

  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(callChannel);

  final title = data['title']?.toString() ?? 'Cuộc gọi đến';
  final body = data['body']?.toString() ?? 'Đang gọi cho bạn...';

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
        fullScreenIntent: true, // Hiển thị trên màn hình khóa
        category: AndroidNotificationCategory.call,
        ongoing: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,
        actions: [
          const AndroidNotificationAction(
            'decline_call',
            'Từ chối',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            'accept_call',
            'Trả lời',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'call_category',
      ),
    ),
    payload: jsonEncode(data),
  );
}
