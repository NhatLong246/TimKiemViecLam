import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/login_controller.dart';
import '../data/models/app_notification_model.dart';
import '../data/models/group_chat_model.dart';
import '../data/models/job_post_model.dart';
import '../routes/app_routes.dart';
import '../screens/attendance/candidate_attendance_screen.dart';
import '../screens/attendance/candidate_work_assignment_screen.dart';
import '../screens/menu_candidate/candidate_reviews_screen.dart';

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
    if (item.isEmployerInterest) {
      final jobId = item.interestJobId;
      if (jobId != null && jobId.isNotEmpty) {
        final snap = await FirebaseFirestore.instance.collection('jobPosts').doc(jobId).get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          data['jobId'] = snap.id;
          final job = JobPostModel.fromMap(data);
          Get.toNamed(AppRoutes.jobDetail, arguments: job);
        } else {
          Get.snackbar('Lỗi', 'Công việc này không còn tồn tại.');
        }
      }
      return;
    }
    final type = item.data['type']?.toString();

    // Các thông báo về hết hạn, giải ngân
    if (type == 'job_work_period_ended' ||
        type == 'disbursement_ready' ||
        type == 'disbursement_reminder' ||
        type == 'disbursement_auto_requested' ||
        type == 'disbursement_pending' ||
        type == 'disbursement_approved' ||
        type == 'disbursement_rejected' ||
        type == 'disbursement_completed' ||
        type == 'group_closed_by_admin') {
      
      final jobId = item.data['jobId']?.toString();
      if (jobId != null && jobId.isNotEmpty) {
        final snap = await FirebaseFirestore.instance.collection('jobPosts').doc(jobId).get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final groupId = data['groupChatId']?.toString();
          
          if (groupId != null && groupId.isNotEmpty) {
            final groupSnap = await FirebaseFirestore.instance.collection('groupChats').doc(groupId).get();
            if (groupSnap.exists) {
              final group = GroupChatModel.fromMap(groupSnap.data() as Map<String, dynamic>, groupSnap.id);
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
          }
        }
      }
      
      // Fallback nếu không có group hoặc có lỗi
      await _openPostManagement(jobId);
      return;
    }

    if (type == 'application_deadline_underfilled') {
      final jobId = item.data['jobId']?.toString();
      await _openPostManagement(jobId);
      return;
    }

    if (item.isWorkAssignment) {
      await openWorkAssignment(item);
      return;
    }

    if (type == 'new_review') {
      Get.to(() => const CandidateReviewsScreen());
      return;
    }
    
    if (type == 'disbursement_received') {
      Get.toNamed(AppRoutes.candidateEarnings);
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

  static Future<void> _openPostManagement(String? jobId) async {
    int initialTab = 0; // Mặc định: Đã đăng
    if (jobId != null && jobId.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance.collection('jobPosts').doc(jobId).get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final status = data['status']?.toString();
          
          if (status == 'pending') {
            initialTab = 1;
          } else if (status == 'draft') {
            initialTab = 2;
          } else if (status == 'closed') {
            initialTab = 5; // Đã HT (6 tabs: Đã đăng(0), Chờ duyệt(1), Nháp(2), Quá hạn(3), Chờ GN(4), Đã HT(5))
          } else if (status == 'rejected') {
            initialTab = 3;
          } else if (status == 'active' || status == 'approved') {
            // Kiểm tra xem có đang chờ giải ngân không
            final noticesSnap = await FirebaseFirestore.instance
                .collection('disbursementNotices')
                .where('jobId', isEqualTo: jobId)
                .where('status', whereIn: ['pending_admin', 'approved'])
                .limit(1)
                .get();
                
            if (noticesSnap.docs.isNotEmpty) {
              initialTab = 4; // Chờ GN
            } else {
              final endDateTs = data['endDate'];
              if (endDateTs is Timestamp) {
                final endDate = endDateTs.toDate();
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final endDay = DateTime(endDate.year, endDate.month, endDate.day);
                if (endDay.isBefore(today)) {
                  initialTab = 3; // Quá hạn
                }
              }
            }
          }
        }
      } catch (_) {}
    }
    Get.toNamed(AppRoutes.postManagement, arguments: {'initialTab': initialTab});
  }
}
