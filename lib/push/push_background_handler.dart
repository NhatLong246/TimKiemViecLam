import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Kênh mặc định — phải trùng với [PushNotificationService.defaultChannelId].
const String kPushDefaultChannelId = 'viecnow_default';
const String kPushDefaultChannelName = 'Thông báo ViecNow';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  if (kIsWeb) return;

  // Android: khi app nền/tắt, FCM tự hiện notification nếu payload có `notification`.
  // iOS / data-only: hiện local notification thủ công.
  final notification = message.notification;
  if (notification == null && message.data.isEmpty) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await plugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  const channel = AndroidNotificationChannel(
    kPushDefaultChannelId,
    kPushDefaultChannelName,
    importance: Importance.high,
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final title =
      notification?.title ?? message.data['title']?.toString() ?? 'ViecNow';
  final body =
      notification?.body ?? message.data['body']?.toString() ?? '';

  await plugin.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        kPushDefaultChannelId,
        kPushDefaultChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}
