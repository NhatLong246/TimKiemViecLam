import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data'; // Cần thiết cho vibrationPattern

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../push/push_background_handler.dart';
import '../../screens/chat/widgets/incoming_call_overlay.dart';
import '../../utils/push_navigation_handler.dart';
import '../services/notification_service.dart';
import '../models/app_notification_model.dart';

class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const callChannelId = 'call_channel_ultimate_v100_final'; // ID CHỐT CUỐI CÙNG

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get localPlugin => _local;

  bool _initialized = false;
  String? _boundUserId;

  /// Firestore listener cho thông báo realtime
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inboxSub;

  /// Lưu ID thông báo đã hiện để không hiện lại
  final Set<String> _shownNotifIds = {};

  /// Timestamp khi bắt đầu listen — chỉ hiện thông báo MỚI HƠN thời điểm này
  DateTime? _listenStartTime;

  /// Bộ đếm notification ID cho local notifications
  int _nextNotifId = 1000;

  /// Theo dõi trạng thái app: foreground hay background
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  bool get _isAppInForeground => _appLifecycleState == AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    debugPrint('📢 [PushLocal] App lifecycle: $state');
  }

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    // Đăng ký theo dõi lifecycle app
    WidgetsBinding.instance.addObserver(this);

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
      // Xóa TẤT CẢ notification cuộc gọi
      _local.cancelAll();
      return;
    }
    if (response.actionId == 'accept_call') {
      // Xóa notification rồi mở cuộc gọi
      _local.cancelAll();
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
      try {
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
              ongoing: false,
              autoCancel: true,
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
      } catch (e) {
        debugPrint('Lỗi hiển thị local notification cuộc gọi: $e');
      }

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

  // ═══════════════════════════════════════════════════════════════════════════
  // FIRESTORE REALTIME LISTENER — Thay thế Cloud Functions cho push
  // Khi có notification mới ghi vào users/{uid}/notifications,
  // app tự bắn local notification ra thanh thông báo điện thoại.
  // ═══════════════════════════════════════════════════════════════════════════

  void _startInboxListener(String userId) {
    _stopInboxListener();
    _shownNotifIds.clear();
    _listenStartTime = DateTime.now();

    debugPrint('📢 [PushLocal] Bắt đầu lắng nghe Firestore inbox cho user: $userId');

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(5);

    _inboxSub = col.snapshots().listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          // Chỉ xử lý doc MỚI ĐƯỢC THÊM
          if (change.type != DocumentChangeType.added) continue;

          final doc = change.doc;
          final data = doc.data();
          if (data == null) continue;

          // Không hiện lại nếu đã hiện
          if (_shownNotifIds.contains(doc.id)) continue;
          _shownNotifIds.add(doc.id);

          // Chỉ hiện thông báo được tạo SAU khi listener bắt đầu
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          if (createdAt == null) continue;
          if (_listenStartTime != null && createdAt.isBefore(_listenStartTime!.subtract(const Duration(seconds: 5)))) {
            continue;
          }

          // Bắn local notification
          _showLocalNotificationFromFirestore(doc.id, data);
        }
      },
      onError: (e) {
        debugPrint('📢 [PushLocal] Lỗi lắng nghe inbox: $e');
      },
    );
  }

  void _stopInboxListener() {
    _inboxSub?.cancel();
    _inboxSub = null;
  }

  /// Hiện local notification từ dữ liệu Firestore
  Future<void> _showLocalNotificationFromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final title = data['title']?.toString() ?? 'ViecNow';
    final body = data['body']?.toString() ?? '';
    final category = data['category']?.toString() ?? 'system';
    final nestedData = data['data'];
    final type = (nestedData is Map ? nestedData['type']?.toString() : null) ?? category;
    final groupId = nestedData is Map ? (nestedData['groupId']?.toString() ?? '') : '';

    // Build payload map cho khi tap vào notification
    final payloadMap = <String, dynamic>{
      'type': type,
      'category': category,
      'title': title,
      'body': body,
      if (groupId.isNotEmpty) 'groupId': groupId,
    };
    if (nestedData is Map) {
      for (final entry in nestedData.entries) {
        payloadMap[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }

    final notifId = _nextNotifId++;

    debugPrint('📢 [PushLocal] Hiện notification: type=$type, title=$title, body=$body, foreground=$_isAppInForeground, lifecycle=$_appLifecycleState');

    if (type == 'call') {
      // === CUỘC GỌI ĐẾN ===
      // Reset cờ _isInCall — cuộc gọi MỚI → cho phép hiện overlay/notification
      IncomingCallOverlay.markCallEnded();
      if (_isAppInForeground) {
        // ĐANG MỞ APP → Chỉ hiện overlay trong app, KHÔNG bắn ra ngoài
        debugPrint('📢 [PushLocal] App foreground → chỉ hiện overlay cuộc gọi');
        try {
          IncomingCallOverlay.show(payloadMap);
        } catch (e) {
          debugPrint('📢 [PushLocal] Lỗi hiện overlay cuộc gọi: $e');
        }
      } else {
        // KHÔNG MỞ APP → Bắn local notification ra ngoài điện thoại
        debugPrint('📢 [PushLocal] App background → bắn notification ra ngoài');
        try {
          await _local.show(
            notifId,
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
                ongoing: false,
                autoCancel: true,
                visibility: NotificationVisibility.public,
                ticker: 'Cuộc gọi đến...',
                actions: [
                  const AndroidNotificationAction('decline_call', 'Từ chối', showsUserInterface: true, cancelNotification: true),
                  const AndroidNotificationAction('accept_call', 'Trả lời', showsUserInterface: true),
                ],
              ),
              iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
            ),
            payload: jsonEncode(payloadMap),
          );
        } catch (e) {
          debugPrint('📢 [PushLocal] Lỗi notification cuộc gọi: $e');
          try {
            await _local.show(
              notifId, title, body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  callChannelId, 'Cuộc gọi đến',
                  importance: Importance.max, priority: Priority.max,
                  icon: '@mipmap/ic_launcher',
                  category: AndroidNotificationCategory.call,
                  visibility: NotificationVisibility.public,
                ),
              ),
              payload: jsonEncode(payloadMap),
            );
          } catch (_) {}
        }
      }
    } else {
      // === THÔNG BÁO THƯỜNG (tin nhắn, job, system...) ===
      if (_isAppInForeground) {
        // ĐANG MỞ APP → Chỉ hiện snackbar trong app
        debugPrint('📢 [PushLocal] App foreground → chỉ hiện snackbar');
        try {
          Get.snackbar(
            title,
            body,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.white,
            colorText: Colors.black87,
            borderRadius: 12,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 4),
            icon: const Icon(Icons.notifications_active, color: Color(0xFF00B2FF)),
            boxShadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
            onTap: (snack) {
              PushNavigationHandler.handlePayload(payloadMap);
            },
          );
        } catch (_) {}
      } else {
        // KHÔNG MỞ APP → Bắn local notification ra ngoài điện thoại
        debugPrint('📢 [PushLocal] App background → bắn notification ra ngoài');
        try {
          await _local.show(
            notifId,
            title,
            body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'viecnow_default',
                'Thông báo chung',
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
                visibility: NotificationVisibility.public,
                ticker: title,
              ),
              iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
            ),
            payload: jsonEncode(payloadMap),
          );
        } catch (e) {
          debugPrint('📢 [PushLocal] Lỗi hiện notification: $e');
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> bindToUser(String userId) async {
    _boundUserId = userId;
    final token = await _fcm.getToken();
    if (token != null) _persistToken(userId, token);

    // BẮT ĐẦU LẮNG NGHE FIRESTORE ĐỂ TỰ BẮN LOCAL NOTIFICATION
    _startInboxListener(userId);
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
    // DỪNG LẮNG NGHE KHI ĐĂNG XUẤT
    _stopInboxListener();

    final token = await _fcm.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({'fcmTokens.$token': FieldValue.delete()});
    }
    _boundUserId = null;
  }
}
