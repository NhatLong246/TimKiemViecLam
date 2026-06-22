import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/constants/full_time_policy.dart';
import '../data/models/job_post_model.dart';
import '../data/models/user_model.dart';
import '../data/services/application_service.dart';
import '../data/services/candidate_eligibility_service.dart';
import '../data/services/group_chat_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/schedule_lock_service.dart';
import '../routes/app_routes.dart';
import '../utils/job_time_helper.dart';
import 'home_controller.dart';
import 'login_controller.dart';

class JobDetailController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ApplicationService _appService = ApplicationService();
  final ScheduleLockService _scheduleLocks = ScheduleLockService();
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
      canApply.value = true;
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
    if (Get.isRegistered<HomeController>()) {
      final cached = Get.find<HomeController>().appliedJobStatus[jobId];
      if (cached != null) {
        applicationStatus.value = cached;
        hasApplied.value = cached == 'pending' || cached == 'accepted';
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
        for (final doc in snap.docs) {
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
        hasApplied.value = status == 'pending' || status == 'accepted';

        if (Get.isRegistered<HomeController>()) {
          if (status == 'pending' ||
              status == 'accepted' ||
              status == 'withdrawn') {
            Get.find<HomeController>().appliedJobStatus[jobId] = status;
          } else {
            Get.find<HomeController>().appliedJobStatus.remove(jobId);
          }
          Get.find<HomeController>().appliedJobStatus.refresh();
        }
      } else {
        applicationStatus.value = 'none';
        hasApplied.value = false;
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

      hasApplied.value = true;
      applicationStatus.value = 'pending';

      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().appliedJobStatus[job.jobId] = 'pending';
        Get.find<HomeController>().appliedJobStatus.refresh();
      }
    } catch (e) {
      final eligibilityError = e is CandidateEligibilityException;
      Get.snackbar(
        eligibilityError
            ? 'Không đủ điều kiện ứng tuyển'
            : 'Không thể ứng tuyển',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: Duration(seconds: eligibilityError ? 8 : 3),
      );
    } finally {
      isApplying.value = false;
    }
  }

  Future<void> cancelApplication(JobPostModel job) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (JobTimeHelper.hasStarted(job)) {
      Get.snackbar(
        job.isFullTimeReferral ? 'Không thể hủy lịch' : 'Không thể hủy',
        job.isFullTimeReferral
            ? 'Đã qua giờ hẹn phỏng vấn, vui lòng liên hệ nhà tuyển dụng.'
            : 'Công việc đã bắt đầu, không thể hủy ứng tuyển.',
      );
      return;
    }

    if (job.isFullTimeReferral &&
        applicationStatus.value == 'accepted' &&
        job.depositStatus == 'released') {
      Get.snackbar(
        'Không thể hủy lịch',
        'Lịch phỏng vấn đã được chốt phí giới thiệu. Vui lòng liên hệ nhà tuyển dụng.',
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
          final jobRef = _db.collection('jobPosts').doc(job.jobId);
          await _db.runTransaction((tx) async {
            final latestApp = await tx.get(doc.reference);
            final latestJob = await tx.get(jobRef);
            if (!latestApp.exists) {
              throw Exception('Không tìm thấy đơn ứng tuyển.');
            }
            if (!latestJob.exists) {
              throw Exception('Không tìm thấy công việc.');
            }
            if ((latestApp.data()?['status'] ?? '').toString() != 'accepted') {
              throw Exception('Đơn ứng tuyển đã được xử lý.');
            }

            final latestJobModel = JobPostModel.fromMap({
              ...latestJob.data()!,
              'jobId': latestJob.id,
            });
            if (latestJobModel.isFullTimeReferral) {
              if (JobTimeHelper.hasStarted(latestJobModel)) {
                throw Exception(
                  'Đã qua giờ hẹn phỏng vấn, vui lòng liên hệ nhà tuyển dụng.',
                );
              }
              if (latestJobModel.depositStatus == 'released' ||
                  latestJobModel.depositStatus == 'refunded') {
                throw Exception(
                  'Lịch phỏng vấn đã được chốt phí giới thiệu. Vui lòng liên hệ nhà tuyển dụng.',
                );
              }
            } else {
              await _scheduleLocks.releaseLocksInTransaction(
                tx: tx,
                candidateId: uid,
                appId: appId,
                windows: ScheduleLockService.buildShiftWindows(latestJobModel),
              );
            }

            tx.update(doc.reference, {
              'status': 'withdrawn',
              if (latestJobModel.isFullTimeReferral)
                'withdrawReason': 'candidate_cancelled_interview',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            tx.update(jobRef, {
              'filledSlots': FieldValue.increment(-1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          });
          if (!job.isFullTimeReferral) {
            await _cancelCandidateSchedules(job.jobId, uid);
            await _leaveAcceptedJobGroup(job, uid);
          }
        } else {
          await doc.reference.delete();
        }

        await _notifyEmployerApplicationWithdrawn(
          job: job,
          appId: appId,
          candidateId: uid,
          wasAccepted: wasAccepted,
          isFullTimeReferral: job.isFullTimeReferral,
        );

        hasApplied.value = false;
        applicationStatus.value = wasAccepted ? 'withdrawn' : 'none';

        if (Get.isRegistered<HomeController>()) {
          if (wasAccepted) {
            Get.find<HomeController>().appliedJobStatus[job.jobId] =
                'withdrawn';
          } else {
            Get.find<HomeController>().appliedJobStatus.remove(job.jobId);
          }
          Get.find<HomeController>().appliedJobStatus.refresh();
        }

        Get.snackbar(
          'Thành công',
          job.isFullTimeReferral && wasAccepted
              ? 'Đã hủy lịch phỏng vấn thành công!'
              : 'Đã hủy ứng tuyển thành công!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade800,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        e.toString().replaceFirst('Exception: ', ''),
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
    required bool isFullTimeReferral,
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
        isFullTimeReferral: isFullTimeReferral,
      );
    } catch (_) {}
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
