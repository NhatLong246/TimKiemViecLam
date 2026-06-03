import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../push/push_background_handler.dart';
import '../../screens/chat/widgets/incoming_call_overlay.dart';
import '../../utils/push_navigation_handler.dart';

/// Push notification thật: FCM + hiển thị local khi app foreground.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const defaultChannelId = kPushDefaultChannelId;
  static const defaultChannelName = kPushDefaultChannelName;
  static const callChannelId = 'call_channel_v2'; // Đổi ID để đảm bảo cập nhật importance

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _boundUserId;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    if (!kIsWeb) {
      tz.initializeTimeZones();
      try {
        final locationInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(locationInfo.identifier));
      } catch (_) {}
    }

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
      
      const callChannel = AndroidNotificationChannel(
        callChannelId,
        'Cuộc gọi đến',
        description: 'Thông báo cuộc gọi video và thoại',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );
      
      const alarmChannel = AndroidNotificationChannel(
        'alarm_channel',
        'Báo thức & Nhắc nhở',
        description: 'Báo động đỏ khi có ca làm việc sắp diễn ra',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.createNotificationChannel(callChannel);
      await androidPlugin?.createNotificationChannel(alarmChannel);
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
      await Permission.notification.request();
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
    if (response.actionId == 'decline_call') {
      return;
    }
    PushNavigationHandler.setPendingFromJson(response.payload);
    PushNavigationHandler.processPendingIfAny();
  }

  Future<void> _showLocalFromMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title']?.toString() ?? 'ViecNow';
    final body = notification?.body ?? data['body']?.toString() ?? '';
    final type = data['type']?.toString();

    // Nếu app đang bật, vẫn hiện Overlay nhưng cũng có thể hiện Notification nếu cần
    if (type == 'call') {
      IncomingCallOverlay.show(data);
      // Tiếp tục hiển thị notification để có nút trả lời nhanh trên thanh trạng thái
    }

    if (title.isEmpty && body.isEmpty) return;

    final payload = data.isNotEmpty ? jsonEncode(data) : null;
    
    AndroidNotificationDetails androidDetails;
    if (type == 'call') {
      androidDetails = const AndroidNotificationDetails(
        callChannelId,
        'Cuộc gọi đến',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        ongoing: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,
        ticker: 'Đang có cuộc gọi đến...',
        actions: [
          AndroidNotificationAction(
            'decline_call',
            'Từ chối',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'accept_call',
            'Trả lời',
            showsUserInterface: true,
          ),
        ],
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        defaultChannelId,
        defaultChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
    }

    await _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'call_category',
        ),
      ),
      payload: payload,
    );
  }
}
