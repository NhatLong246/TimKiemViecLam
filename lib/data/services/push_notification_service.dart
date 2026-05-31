import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../push/push_background_handler.dart';
import '../../utils/push_navigation_handler.dart';

/// Push notification thật: FCM + hiển thị local khi app foreground.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const defaultChannelId = kPushDefaultChannelId;
  static const defaultChannelName = kPushDefaultChannelName;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _boundUserId;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    if (!kIsWeb && Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        defaultChannelId,
        defaultChannelName,
        description: 'Thông báo việc làm, tin nhắn, giải ngân',
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await requestPermission();

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      PushNavigationHandler.setPending(initial.data);
    }

    _fcm.onTokenRefresh.listen((token) {
      final uid = _boundUserId;
      if (uid != null && uid.isNotEmpty) {
        _persistToken(uid, token);
      }
    });
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (!status.isGranted && !status.isLimited) {
        // Android < 13 không cần runtime permission.
      }
    }

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> bindToUser(String userId) async {
    if (kIsWeb || userId.isEmpty) return;
    _boundUserId = userId;

    final token = await _fcm.getToken();
    if (token != null) {
      await _persistToken(userId, token);
    }

    await PushNavigationHandler.processPendingIfAny();
  }

  Future<void> unbindUser(String userId) async {
    if (kIsWeb || userId.isEmpty) return;

    final token = await _fcm.getToken();
    if (token != null) {
      await _removeToken(userId, token);
    }

    if (_boundUserId == userId) {
      _boundUserId = null;
    }

    try {
      await _fcm.deleteToken();
    } catch (_) {}
  }

  Future<void> _persistToken(String userId, String token) async {
    final platform = !kIsWeb && Platform.isIOS ? 'ios' : 'android';
    final ref = FirebaseFirestore.instance.collection('users').doc(userId);
    final payload = {
      'fcmTokens.$token': {
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await ref.update(payload);
    } catch (_) {
      await ref.set(payload, SetOptions(merge: true));
    }
  }

  Future<void> _removeToken(String userId, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'fcmTokens.$token': FieldValue.delete(),
    });
  }

  void _onForegroundMessage(RemoteMessage message) {
    _showLocalFromMessage(message);
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    PushNavigationHandler.handlePayload(message.data);
  }

  void _onLocalTap(NotificationResponse response) {
    PushNavigationHandler.setPendingFromJson(response.payload);
    PushNavigationHandler.processPendingIfAny();
  }

  Future<void> _showLocalFromMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title =
        notification?.title ?? data['title']?.toString() ?? 'ViecNow';
    final body =
        notification?.body ?? data['body']?.toString() ?? '';

    if (title.isEmpty && body.isEmpty) return;

    final payload = data.isNotEmpty ? jsonEncode(data) : null;

    await _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          defaultChannelId,
          defaultChannelName,
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
      payload: payload,
    );
  }
}
