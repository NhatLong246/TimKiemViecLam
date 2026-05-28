import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/login_controller.dart';
import '../data/models/app_notification_model.dart';
import '../data/models/group_chat_model.dart';
import '../routes/app_routes.dart';
import '../screens/attendance/candidate_attendance_screen.dart';
import '../screens/attendance/candidate_work_assignment_screen.dart';

/// Điều hướng khi người dùng nhấn một mục trong danh sách thông báo.
class NotificationNavigation {
  NotificationNavigation._();

  static Future<void> handleTap(
    BuildContext context,
    AppNotificationItem item,
  ) async {
    if (item.isAttendanceNotification) {
      await openAttendance(context, item);
      return;
    }
    if (item.isWorkAssignment) {
      await openWorkAssignment(item);
      return;
    }
  }

  static Future<void> openAttendance(
    BuildContext context,
    AppNotificationItem item,
  ) async {
    final groupId = item.attendanceGroupId;
    if (groupId == null || groupId.isEmpty) {
      Get.snackbar('Lỗi', 'Thiếu thông tin nhóm điểm danh');
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('groupChats')
        .doc(groupId)
        .get();
    if (!context.mounted) return;
    if (!snap.exists) {
      Get.snackbar('Lỗi', 'Không tìm thấy nhóm việc làm');
      return;
    }

    final group = GroupChatModel.fromMap(
      snap.data() as Map<String, dynamic>,
      snap.id,
    );
    final role = Get.find<AuthController>().currentUser?.role ?? 'candidate';

    if (role == 'employer') {
      Get.toNamed(
        AppRoutes.attendance,
        arguments: {
          'groupId': group.groupId,
          'jobId': group.jobId,
          'jobTitle': group.jobTitle,
          'memberIds': group.memberIds,
          'employerId': group.employerId,
        },
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CandidateAttendanceScreen(group: group),
      ),
    );
  }

  static Future<void> openWorkAssignment(AppNotificationItem item) async {
    final groupId = item.workAssignmentGroupId;
    if (groupId == null || groupId.isEmpty) return;

    await Get.to(
      () => CandidateWorkAssignmentScreen(
        initialDate: item.workAssignmentDate,
      ),
      arguments: {
        'groupId': groupId,
        'date': item.workAssignmentDate ?? '',
      },
    );
  }
}
