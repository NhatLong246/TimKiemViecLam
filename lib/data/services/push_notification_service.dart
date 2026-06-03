import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data'; // Cần thiết cho vibrationPattern

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../push/push_background_handler.dart';
import '../../screens/chat/widgets/incoming_call_overlay.dart';
import '../../utils/push_navigation_handler.dart';
import '../services/notification_service.dart';
import '../models/app_notification_model.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const callChannelId = 'call_channel_ultimate_v100_final'; // ID CHỐT CUỐI CÙNG

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _boundUserId;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    if (!kIsWeb && Platform.isAndroid) {
      final callChannel = AndroidNotificationChannel(
        callChannelId,
        'Cuộc gọi đến',
        description: 'Thông báo cuộc gọi video và thoại khẩn cấp',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      );
      
      const defaultChannel = AndroidNotificationChannel(
        'viecnow_default',
        'Thông báo chung',
        description: 'Thông báo tin nhắn và cập nhật hệ thống',
        importance: Importance.max, // Đảm bảo push rớt xuống (Heads-up)
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(callChannel);
        await androidPlugin.createNotificationChannel(defaultChannel);
      }
    }

    await requestPermission();

    // IN TOKEN RA ĐỂ TEST
    String? token = await _fcm.getToken();
    debugPrint('FCM TOKEN CỦA BẠN: $token');

    FirebaseMessaging.onMessage.listen((msg) => _showLocalFromMessage(msg));
    FirebaseMessaging.onMessageOpenedApp.listen((msg) => PushNavigationHandler.handlePayload(msg.data));
  }

  Future<void> requestPermission() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      await Permission.notification.request();
      if (!await Permission.systemAlertWindow.isGranted) {
        await Permission.systemAlertWindow.request();
      }
    }
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
  }

  void _onLocalTap(NotificationResponse response) {
    if (response.actionId == 'decline_call') {
      _local.cancel(response.id ?? 0);
      return;
    }
    final data = jsonDecode(response.payload ?? '{}');
    PushNavigationHandler.handlePayload(data);
  }

  Future<void> _showLocalFromMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString();
    final title = message.notification?.title ?? data['title']?.toString() ?? 'Cuộc gọi đến';
    final body = message.notification?.body ?? data['body']?.toString() ?? 'Đang gọi video cho bạn...';

    if (type == 'call') {
      // 1. LƯU VÀO DANH SÁCH THÔNG BÁO (Trong app)
      if (_boundUserId != null) {
        NotificationService().sendToUser(
          userId: _boundUserId!,
          title: title,
          body: body,
          category: NotificationCategory.message,
          data: data,
        );
      }

      // 2. HIỆN THANH THÔNG BÁO ĐẨY XUỐNG (Heads-up)
      await _local.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
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
            ticker: 'Cuộc gọi đến...',
            actions: [
              AndroidNotificationAction('decline_call', 'Từ chối', showsUserInterface: true, cancelNotification: true),
              AndroidNotificationAction('accept_call', 'Trả lời', showsUserInterface: true),
            ],
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
        payload: jsonEncode(data),
      );

      // 3. HIỆN Ô CUỘC GỌI TRONG APP
      IncomingCallOverlay.show(data);
    } else {
      // 4. HIỆN SNACKBAR CHO TIN NHẮN BÌNH THƯỜNG KHI ĐANG Ở TRONG APP
      final titleText = message.notification?.title ?? data['title']?.toString() ?? 'Thông báo mới';
      final bodyText = message.notification?.body ?? data['body']?.toString() ?? 'Bạn có một tin nhắn mới';
      
      Get.snackbar(
        titleText,
        bodyText,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.white,
        colorText: Colors.black87,
        borderRadius: 12,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.notifications_active, color: Color(0xFF00B2FF)),
        boxShadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        onTap: (snack) {
          PushNavigationHandler.handlePayload(data);
        },
      );
    }
  }

  Future<void> bindToUser(String userId) async {
    _boundUserId = userId;
    final token = await _fcm.getToken();
    if (token != null) _persistToken(userId, token);
  }

  Future<void> _persistToken(String userId, String token) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(userId);
    try {
      await ref.update({
        'fcmTokens.$token': {'platform': Platform.isIOS ? 'ios' : 'android', 'updatedAt': FieldValue.serverTimestamp()},
      });
    } catch (_) {
      await ref.set({
        'fcmTokens': {token: {'platform': Platform.isIOS ? 'ios' : 'android', 'updatedAt': FieldValue.serverTimestamp()}},
      }, SetOptions(merge: true));
    }
  }

  Future<void> unbindUser(String userId) async {
    final token = await _fcm.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({'fcmTokens.$token': FieldValue.delete()});
    }
    _boundUserId = null;
  }
}
