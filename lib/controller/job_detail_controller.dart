import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../data/models/user_model.dart';
import '../data/models/job_post_model.dart';
import '../data/services/application_service.dart';
import '../routes/app_routes.dart';

class JobDetailController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ApplicationService _appService = ApplicationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Rx<UserModel?> employer = Rx<UserModel?>(null);
  final RxBool isLoadingEmployer = true.obs;
  final RxBool isApplying = false.obs;

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

    try {
      isApplying.value = true;
      await _appService.applyForJob(
        jobId: job.jobId,
        employerId: job.employerId,
        candidateId: user.uid,
      );
      Get.snackbar(
        'Thành công',
        'Đã gửi đơn ứng tuyển thành công!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
      );
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
}
