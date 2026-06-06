import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/job_post_model.dart';
import '../../data/services/group_chat_service.dart';
import '../../routes/app_routes.dart';
import '../../controller/job_post_controller.dart';

/// Điều hướng từ Quản lý bài đăng NTD.
class PostManagementActions {
  static final _groups = GroupChatService();

  static void viewDetail(JobPostModel post) {
    Get.toNamed(AppRoutes.jobDetail, arguments: post);
  }

  static void editPost(JobPostModel post) {
    if (post.jobType == 'full_time') {
      Get.toNamed(AppRoutes.createFulltimePost, arguments: post);
    } else {
      Get.toNamed(AppRoutes.createPost, arguments: post);
    }
  }

  static void openCandidates(JobPostModel post) {
    Get.toNamed(
      AppRoutes.employerCandidates,
      arguments: {'jobId': post.jobId, 'jobType': post.jobType},
    );
  }

  static Future<void> openGroup(JobPostModel post) async {
    if (post.isFullTimeReferral) {
      Get.snackbar(
        'Không khả dụng',
        'Full-time chỉ giới thiệu tin — ViecNow không quản lý nhóm chat.',
      );
      return;
    }
    final gid = post.groupChatId;
    if (gid == null || gid.isEmpty) {
      Get.snackbar(
        'Chưa có nhóm',
        'Duyệt ít nhất một ứng viên để tạo nhóm chat.',
      );
      return;
    }
    final g = await _groups.getGroup(gid);
    if (g == null) {
      Get.snackbar('Lỗi', 'Không tìm thấy nhóm chat');
      return;
    }
    Get.toNamed(AppRoutes.groupManagement, arguments: g);
  }

  static Future<void> openAttendance(JobPostModel post) async {
    if (post.isFullTimeReferral) {
      Get.snackbar(
        'Không khả dụng',
        'Full-time chỉ giới thiệu tin — ViecNow không quản lý điểm danh.',
      );
      return;
    }
    final gid = post.groupChatId;
    if (gid == null || gid.isEmpty) {
      Get.snackbar('Chưa có nhóm', 'Cần nhóm chat để điểm danh');
      return;
    }
    final g = await _groups.getGroup(gid);
    if (g == null) return;
    Get.toNamed(
      AppRoutes.attendance,
      arguments: {
        'groupId': g.groupId,
        'jobId': g.jobId,
        'jobTitle': g.jobTitle,
        'memberIds': g.memberIds,
        'employerId': g.employerId,
      },
    );
  }

  static Future<void> openAttendanceSummary(JobPostModel post) async {
    if (post.isFullTimeReferral) {
      Get.snackbar(
        'Không khả dụng',
        'Full-time chỉ giới thiệu tin — không có điểm danh trên ViecNow.',
      );
      return;
    }
    final gid = post.groupChatId;
    if (gid == null || gid.isEmpty) {
      Get.snackbar('Chưa có nhóm', 'Chưa có dữ liệu điểm danh');
      return;
    }
    final g = await _groups.getGroup(gid);
    if (g == null) return;
    Get.toNamed(AppRoutes.jobAttendanceSummary, arguments: g);
  }

  static void openComplaints() {
    Get.toNamed(AppRoutes.complaintsCatalog);
  }

  static Future<void> openDisbursement(JobPostModel post) async {
    if (post.isFullTimeReferral) {
      Get.snackbar(
        'Không khả dụng',
        'Full-time chỉ giới thiệu tin — ViecNow không giải ngân lương Full-time.',
      );
      return;
    }
    final gid = post.groupChatId;
    if (gid == null || gid.isEmpty) {
      Get.snackbar('Chưa có nhóm', 'Hoàn tất tuyển dụng và điểm danh trước');
      return;
    }
    final g = await _groups.getGroup(gid);
    if (g == null) return;
    Get.toNamed(AppRoutes.jobDayEndFlow, arguments: {'group': g});
  }

  static Future<bool> confirmClose(
    BuildContext context,
    JobPostModel post,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              post.isFullTimeReferral && post.filledSlots > 0
                  ? 'Đóng bài & quyết toán?'
                  : 'Đóng bài đăng?',
            ),
            content: Text(
              post.isFullTimeReferral && post.filledSlots > 0
                  ? 'Bài đã có ứng viên được duyệt. Hệ thống sẽ thu phí giới thiệu theo số ứng viên đã duyệt và hoàn phần còn lại. Ứng viên đã duyệt vẫn giữ lịch phỏng vấn.'
                  : post.isFullTimeReferral
                  ? 'Bài đăng sẽ không nhận ứng viên mới. '
                        'Ứng viên đã apply vẫn do NTD tự liên hệ — ViecNow không quản lý Full-time.'
                  : 'Bài đăng sẽ không nhận ứng viên mới. '
                        'Nhóm chat vẫn hoạt động cho đến khi giải ngân/giải tán.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  post.isFullTimeReferral && post.filledSlots > 0
                      ? 'Quyết toán'
                      : 'Đóng',
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Future<bool> confirmDelete(
    BuildContext context,
    JobPostModel post,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              post.isFullTimeReferral && post.filledSlots > 0
                  ? 'Đóng bài & quyết toán?'
                  : 'Xóa bài đăng?',
            ),
            content: Text(
              post.isFullTimeReferral && post.filledSlots > 0
                  ? 'Bài đã có ứng viên được duyệt nên không thể xóa trắng. Hệ thống sẽ đóng bài, thu phí giới thiệu theo số ứng viên đã duyệt và hoàn phần còn lại.'
                  : 'Thao tác không thể hoàn tác.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  post.isFullTimeReferral && post.filledSlots > 0
                      ? 'Quyết toán'
                      : 'Xóa',
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Future<bool> confirmCancelJob(
    BuildContext context,
    JobPostModel post,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hủy công việc?'),
            content: Text(
              post.filledSlots >= post.slots
                  ? 'Công việc đã đủ người. Việc hủy công việc sẽ khiến bạn mất 10% ngân sách cọc để đền bù cho ứng viên.'
                  : 'Công việc chưa đủ người, việc hủy sẽ hoàn lại 100% ngân sách.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Đóng'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(ctx, true);
                  final controller = Get.find<JobPostController>();
                  controller.cancelPost(post);
                },
                child: const Text('Hủy Job'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
