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

  final notification = message.notification;
  final data = message.data;
  if (notification == null && data.isEmpty) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await plugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  final type = data['type']?.toString();
  final title = notification?.title ?? data['title']?.toString() ?? 'ViecNow';
  final body = notification?.body ?? data['body']?.toString() ?? '';

  if (type == 'call') {
    const callChannel = AndroidNotificationChannel(
      'call_channel',
      'Cuộc gọi',
      description: 'Thông báo cuộc gọi đến',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callChannel);

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
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          ongoing: true,
          autoCancel: false,
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
  } else {
    const channel = AndroidNotificationChannel(
      kPushDefaultChannelId,
      kPushDefaultChannelName,
      importance: Importance.high,
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

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
      payload: jsonEncode(data),
    );
  }
}
