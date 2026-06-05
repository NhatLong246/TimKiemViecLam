import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../controller/login_controller.dart';
import '../controller/messaging_controller.dart';
import '../data/models/app_notification_model.dart';
import '../routes/app_routes.dart';
import '../screens/chat/call_screen.dart';
import '../screens/messaging/chat_room_screen.dart';
import '../screens/notification/notification_screen.dart';
import '../screens/alarm/alarm_alert_screen.dart';
import '../screens/menu_candidate/candidate_reviews_screen.dart';
import 'messaging_bootstrap.dart';
import 'notification_navigation.dart';

/// Điều hướng khi người dùng chạm push notification (FCM / local).
class PushNavigationHandler {
  PushNavigationHandler._();

  static Map<String, dynamic>? _pendingPayload;

  static void setPending(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    _pendingPayload = Map<String, dynamic>.from(data);
  }

  static void setPendingFromJson(String? json) {
    if (json == null || json.isEmpty) return;
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        setPending(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
  }

  /// Gọi sau khi đăng nhập / khôi phục phiên — khi navigator đã sẵn sàng.
  static Future<void> processPendingIfAny() async {
    final payload = _pendingPayload;
    if (payload == null || payload.isEmpty) return;

    final user = Get.find<AuthController>().currentUser;
    if (user == null) return;

    _pendingPayload = null;
    await _navigate(payload, user.role);
  }

  static Future<void> handlePayload(Map<String, dynamic> data) async {
    final user = Get.find<AuthController>().currentUser;
    if (user == null) {
      setPending(data);
      return;
    }
    await _navigate(data, user.role);
  }

  static Future<void> _navigate(
    Map<String, dynamic> data,
    String role,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final type = data['type']?.toString() ?? '';
    final groupId = data['groupId']?.toString() ?? '';

    if (type == 'alarm') {
      data['title'] = data['title'] ?? 'Thông báo Khẩn!';
      data['body'] = data['body'] ?? 'Bạn có lịch làm việc sắp diễn ra.';
      await Get.to(() => AlarmAlertScreen(payload: data));
      return;
    }

    if (type == 'call' && groupId.isNotEmpty) {
      final isVideo = data['isVideo']?.toString() == 'true';
      final roomUrl = data['roomUrl']?.toString() ?? '';
      if (roomUrl.isNotEmpty) {
        if (Get.isRegistered<MessagingController>()) {
          Get.find<MessagingController>().openChatByGroupId(groupId); // Đảm bảo init thread
        } else {
          MessagingBootstrap.ensureController().openChatByGroupId(groupId);
        }

        // Lấy tên nhóm/job thực tế từ Firestore
        String groupName = data['title']?.toString() ?? 'Cuộc gọi';
        try {
          final groupSnap = await FirebaseFirestore.instance
              .collection('groupChats')
              .doc(groupId)
              .get();
          if (groupSnap.exists) {
            final gData = groupSnap.data() ?? {};
            final jobTitle = (gData['jobTitle'] ?? '').toString();
            final chatType = (gData['chatType'] ?? '').toString();
            if (chatType == 'group' && jobTitle.isNotEmpty) {
              groupName = 'Nhóm $jobTitle';
            } else if (jobTitle.isNotEmpty) {
              groupName = jobTitle;
            }
          }
        } catch (_) {}
        
        final user = Get.find<AuthController>().currentUser;
        if (user != null) {
          await Get.to(() => CallScreen(
            isVideo: isVideo,
            groupName: groupName,
            userId: user.id,
            callId: roomUrl,
            userName: user.fullName,
          ));
        }
        return;
      }
    }

    if (type == 'message' && groupId.isNotEmpty) {
      if (Get.isRegistered<MessagingController>()) {
        await Get.find<MessagingController>().markConversationRead(groupId);
      } else {
        MessagingBootstrap.ensureController().markConversationRead(groupId);
      }
      await Get.to(() => ChatRoomScreen(groupId: groupId));
      return;
    }

    if (type == 'attendance_request' ||
        type == 'attendance_result' ||
        data['phase']?.toString() == 'check_in' ||
        data['phase']?.toString() == 'check_out') {
      if (groupId.isEmpty) {
        _openNotificationHub(role);
        return;
      }
      final item = AppNotificationItem(
        id: '',
        title: data['title']?.toString() ?? '',
        body: data['body']?.toString() ?? '',
        createdAt: DateTime.now(),
        category: NotificationCategory.job,
        data: data,
      );
      final ctx = Get.context;
      if (ctx != null && ctx.mounted) {
        await NotificationNavigation.handleTap(ctx, item);
      }
      return;
    }

    if (type == 'work_assignment' && groupId.isNotEmpty) {
      final item = AppNotificationItem(
        id: '',
        title: data['title']?.toString() ?? '',
        body: data['body']?.toString() ?? '',
        createdAt: DateTime.now(),
        category: NotificationCategory.job,
        data: data,
      );
      await NotificationNavigation.openWorkAssignment(item);
      return;
    }

    if (type == 'employer_interest') {
      final jobId = data['jobId']?.toString();
      if (jobId != null && jobId.isNotEmpty) {
        await Get.toNamed(AppRoutes.jobDetail, arguments: {'jobId': jobId});
      }
      return;
    }

    if (role == 'employer') {
      if (type == 'application_deadline_underfilled') {
        await Get.toNamed(AppRoutes.postManagement);
        return;
      }
      if (type == 'application' &&
          data['jobId']?.toString().isNotEmpty == true) {
        await Get.toNamed(
          AppRoutes.employerCandidates,
          arguments: {'jobId': data['jobId']},
        );
        return;
      }
      if (type.startsWith('disbursement') && groupId.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('groupChats')
            .doc(groupId)
            .get();
        if (snap.exists) {
          await Get.toNamed(AppRoutes.jobDayEndFlow, arguments: snap.data());
          return;
        }
      }
      if (type.contains('complaint')) {
        await Get.toNamed(AppRoutes.complaintsCatalog);
        return;
      }
      await Get.toNamed(AppRoutes.employerNotifications);
      return;
    }

    if (role == 'admin') {
      if (type.startsWith('disbursement')) {
        await Get.toNamed(AppRoutes.adminDisbursements);
        return;
      }
      if (type.contains('complaint')) {
        await Get.toNamed(AppRoutes.complaintsCatalog);
        return;
      }
      await Get.toNamed(AppRoutes.adminHome);
      return;
    }

    if (role == 'candidate') {
      if (type == 'new_review') {
        await Get.to(() => const CandidateReviewsScreen());
        return;
      }
      if (type == 'disbursement_received') {
        await Get.toNamed(AppRoutes.candidateEarnings);
        return;
      }
    }

    _openNotificationHub(role);
  }

  static void _openNotificationHub(String role) {
    if (role == 'employer') {
      Get.toNamed(AppRoutes.employerNotifications);
    } else {
      Get.to(() => const NotificationScreen());
    }
  }
}
