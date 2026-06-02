import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../data/constants/full_time_policy.dart';
import '../data/models/user_model.dart';
import '../data/models/job_post_model.dart';
import '../data/services/application_service.dart';
import '../data/services/group_chat_service.dart';
import '../data/services/notification_service.dart';
import '../routes/app_routes.dart';
import 'login_controller.dart';
import 'home_controller.dart';

class JobDetailController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ApplicationService _appService = ApplicationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Rx<UserModel?> employer = Rx<UserModel?>(null);
  final RxBool isLoadingEmployer = true.obs;
  final RxBool isApplying = false.obs;
  final RxBool canApply = true.obs;
  final RxString currentRole = ''.obs;
  final RxBool hasApplied = false.obs;
  final RxString applicationStatus = 'none'.obs;

  @override
  void onInit() {
    super.onInit();
    _syncCurrentRole();
  }

  Future<void> _syncCurrentRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      canApply.value = true; // Chưa đăng nhập: vẫn cho bấm để điều hướng login.
      currentRole.value = '';
      return;
    }

    final authCtrl = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    final cachedRole = authCtrl?.currentUser?.role;
    if (cachedRole != null && cachedRole.isNotEmpty) {
      currentRole.value = cachedRole;
      canApply.value = cachedRole == 'candidate';
      return;
    }

    try {
      final doc = await _db.collection('users').doc(uid).get();
      final role = (doc.data()?['role'] ?? 'candidate').toString();
      currentRole.value = role;
      canApply.value = role == 'candidate';
    } catch (_) {
      canApply.value = true;
      currentRole.value = '';
    }
  }

  void fetchEmployerInfo(String employerId) async {
    isLoadingEmployer.value = true;
    try {
      final doc = await _db.collection('users').doc(employerId).get();
      if (doc.exists) {
        employer.value = UserModel.fromMap(doc.data()!);
      }
    } catch (e) {
      print('Lỗi khi fetch employer: $e');
    } finally {
      isLoadingEmployer.value = false;
    }
  }

  Future<void> checkApplicationStatus(String jobId) async {
    // Lấy ngay trạng thái hiện tại từ HomeController (nếu có) để chống nháy màn hình (flicker)
    if (Get.isRegistered<HomeController>()) {
      final cached = Get.find<HomeController>().appliedJobStatus[jobId];
      if (cached != null) {
        applicationStatus.value = cached;
        hasApplied.value = (cached == 'pending' || cached == 'accepted');
      } else {
        applicationStatus.value = 'none';
        hasApplied.value = false;
      }
    } else {
      hasApplied.value = false;
      applicationStatus.value = 'none';
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await _db
          .collection('applications')
          .where('jobId', isEqualTo: jobId)
          .where('candidateId', isEqualTo: uid)
          .get();
      if (snap.docs.isNotEmpty) {
        var status = 'none';
        for (var doc in snap.docs) {
          final s = doc.data()['status'] as String?;
          if (s == 'accepted') {
            status = 'accepted';
            break;
          }
          if (s == 'pending') {
            status = 'pending';
          }
          if (status == 'none' &&
              (s == 'withdrawn' || s == 'cancelled' || s == 'rejected')) {
            status = s!;
          }
        }
        applicationStatus.value = status;
        hasApplied.value = (status == 'pending' || status == 'accepted');

        // Đồng bộ về HomeController
        if (Get.isRegistered<HomeController>()) {
          if (status == 'pending' ||
              status == 'accepted' ||
              status == 'withdrawn') {
            // Giữ lại các trạng thái cần theo dõi - đặc biệt KHÔNG xóa withdrawn
            Get.find<HomeController>().appliedJobStatus[jobId] = status;
          } else {
            // Chỉ xóa khi status = 'none' (chưa từng ứng tuyển)
            Get.find<HomeController>().appliedJobStatus.remove(jobId);
          }
          Get.find<HomeController>().appliedJobStatus.refresh();
        }
      } else {
        applicationStatus.value = 'none';
        hasApplied.value = false;
        // Không có document nào → xóa khỏi cache
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().appliedJobStatus.remove(jobId);
          Get.find<HomeController>().appliedJobStatus.refresh();
        }
      }
    } catch (e) {
      print('Lỗi checkApplicationStatus: $e');
    }
  }

  Future<void> applyJob(JobPostModel job) async {
    final user = _auth.currentUser;
    if (user == null) {
      Get.snackbar(
        'Yêu cầu đăng nhập',
        'Vui lòng đăng nhập để ứng tuyển',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade800,
      );
      Get.toNamed(AppRoutes.login);
      return;
    }
    await _syncCurrentRole();
    if (!canApply.value) {
      Get.snackbar(
        'Không thể ứng tuyển',
        'Tài khoản NTD/Admin không thể ứng tuyển. Hãy dùng tài khoản Ứng viên.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      return;
    }

    try {
      isApplying.value = true;
      await _appService.applyForJob(
        jobId: job.jobId,
        employerId: job.employerId,
        candidateId: user.uid,
      );
      Get.snackbar(
        'Thành công',
        job.isFullTimeReferral
            ? kFullTimeApplySuccess
            : 'Đã gửi đơn ứng tuyển thành công!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        duration: Duration(seconds: job.isFullTimeReferral ? 5 : 3),
      );

      // Update local state to reflect UI changes
      hasApplied.value = true;
      applicationStatus.value = 'pending';

      // Update HomeController if exists
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().appliedJobStatus[job.jobId] = 'pending';
        Get.find<HomeController>().appliedJobStatus.refresh();
      }
    } catch (e) {
      Get.snackbar(
        'Không thể ứng tuyển',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    } finally {
      isApplying.value = false;
    }
  }

  Future<void> cancelApplication(JobPostModel job) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Chỉ cho phép hủy nếu chưa tới ngày làm
    if (DateTime.now().isAfter(job.startDate)) {
      Get.snackbar(
        'Không thể hủy',
        'Công việc đã bắt đầu, không thể hủy ứng tuyển.',
      );
      return;
    }

    try {
      isApplying.value = true;
      final snap = await _db
          .collection('applications')
          .where('jobId', isEqualTo: job.jobId)
          .where('candidateId', isEqualTo: uid)
          .get();
      // Tìm doc pending hoặc accepted
      final validDocs = snap.docs.where((d) {
        final s = d.data()['status'] as String?;
        return s == 'pending' || s == 'accepted';
      }).toList();
      if (validDocs.isNotEmpty) {
        final doc = validDocs.first;
        final data = doc.data();
        final status = data['status'] as String?;
        final wasAccepted = status == 'accepted';
        final appId = (data['appId'] ?? doc.id).toString();

        if (wasAccepted) {
          // Đã được nhận mà hủy → cập nhật thành 'withdrawn' (không xóa)
          // để HomeController biết không cho ứng tuyển lại
          await doc.reference.update({
            'status': 'withdrawn',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await _db.collection('jobPosts').doc(job.jobId).update({
            'filledSlots': FieldValue.increment(-1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await _cancelCandidateSchedules(job.jobId, uid);
          await _leaveAcceptedJobGroup(job, uid);
        } else {
          // Đang chờ duyệt mà hủy → xóa hẳn (cho phép ứng tuyển lại)
          await doc.reference.delete();
        }

        await _notifyEmployerApplicationWithdrawn(
          job: job,
          appId: appId,
          candidateId: uid,
          wasAccepted: wasAccepted,
        );

        hasApplied.value = false;
        // Hủy từ pending → cho ứng tuyển lại (none/xanh)
        // Hủy từ accepted → không cho ứng tuyển lại (withdrawn/xám)
        applicationStatus.value = wasAccepted ? 'withdrawn' : 'none';

        // Update HomeController cache
        if (Get.isRegistered<HomeController>()) {
          if (wasAccepted) {
            // Giữ lại trong map với status withdrawn để dashboard hiển thị xám
            Get.find<HomeController>().appliedJobStatus[job.jobId] =
                'withdrawn';
          } else {
            Get.find<HomeController>().appliedJobStatus.remove(job.jobId);
          }
          Get.find<HomeController>().appliedJobStatus.refresh();
        }

        Get.snackbar(
          'Thành công',
          'Đã hủy ứng tuyển thành công!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade800,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể hủy ứng tuyển.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    } finally {
      isApplying.value = false;
    }
  }

  Future<void> _leaveAcceptedJobGroup(JobPostModel job, String userId) async {
    final groupId = await _resolveJobGroupId(job);
    if (groupId == null || groupId.isEmpty) return;
    await GroupChatService().leaveGroup(groupId, userId);
  }

  Future<String?> _resolveJobGroupId(JobPostModel job) async {
    final fromPost = job.groupChatId;
    if (fromPost != null && fromPost.isNotEmpty) return fromPost;

    final snap = await _db
        .collection('groupChats')
        .where('jobId', isEqualTo: job.jobId)
        .where('chatType', isEqualTo: 'group')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<void> _cancelCandidateSchedules(
    String jobId,
    String candidateId,
  ) async {
    final snap = await _db
        .collection('schedules')
        .where('candidateId', isEqualTo: candidateId)
        .get();
    final batch = _db.batch();
    var updated = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['jobId'] ?? '').toString() != jobId) continue;
      final status = (data['status'] ?? '').toString();
      if (status == 'cancelled' || status == 'completed') continue;
      batch.update(doc.reference, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      updated++;
    }
    if (updated > 0) await batch.commit();
  }

  Future<void> _notifyEmployerApplicationWithdrawn({
    required JobPostModel job,
    required String appId,
    required String candidateId,
    required bool wasAccepted,
  }) async {
    try {
      final name = await _candidateDisplayName(candidateId);
      await NotificationService.notifyApplicationWithdrawn(
        employerId: job.employerId,
        jobTitle: job.title,
        candidateName: name,
        wasAccepted: wasAccepted,
        jobId: job.jobId,
        appId: appId,
        candidateId: candidateId,
      );
    } catch (_) {
      // Không chặn thao tác hủy nếu chỉ lỗi gửi thông báo.
    }
  }

  Future<String> _candidateDisplayName(String candidateId) async {
    try {
      final doc = await _db.collection('users').doc(candidateId).get();
      final data = doc.data() ?? {};
      final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
          .trim();
      if (name.isNotEmpty) return name;
    } catch (_) {}
    return 'Ứng viên';
  }
}
