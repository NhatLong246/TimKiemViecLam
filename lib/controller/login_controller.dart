import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/login_auth_service.dart';
import '../data/models/user_model.dart';
import '../utils/preferences_helper.dart';
import 'package:get/get.dart';
import '../data/services/attendance_auto_notify_service.dart';
import '../data/services/push_notification_service.dart';
import '../utils/messaging_bootstrap.dart';
import '../utils/push_navigation_handler.dart';
import '../routes/app_routes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/services/alarm_manager_service.dart';

import 'employer_profile_controller.dart';
import 'job_post_controller.dart';
import 'employer_notification_controller.dart';
import 'employer_home_controller.dart';
import 'messaging_controller.dart';
class AuthController extends GetxController {
  final LoginAuthService _authService = LoginAuthService();
  UserModel? currentUser;
  Future<void>? _prepareSessionFuture;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  /// Mở app: chỉ giữ đăng nhập nếu đã tick **Ghi nhớ đăng nhập** lần trước.
  Future<void> prepareSessionOnStartup() {
    if (_prepareSessionFuture != null) return _prepareSessionFuture!;
    
    _prepareSessionFuture = () async {
      try {
        await _prepareSessionOnStartupImpl().timeout(const Duration(seconds: 12));
      } catch (e) {
        Get.snackbar('Lỗi session', e.toString());
        currentUser = null;
        update();
      }
    }();
    
    return _prepareSessionFuture!;
  }

  Future<void> _prepareSessionOnStartupImpl() async {

    final user = await _authService.restoreSessionFromFirebase();
    if (user != null) {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .get();
      final remoteSessionId = docSnap.data()?['currentSessionId'] as String?;
      final localSessionId = await PreferencesHelper.getOrCreateDeviceId();

      if (remoteSessionId != null &&
          remoteSessionId.isNotEmpty &&
          remoteSessionId != localSessionId) {
        // Session bị lấy bởi thiết bị khác khi app tắt
        await _authService.logout();
        currentUser = null;
        update();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.snackbar(
            'Cảnh báo bảo mật',
            'Đăng nhập ở máy khác. Remote: $remoteSessionId, Local: $localSessionId',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 10),
          );
        });
        return;
      }

      if (remoteSessionId != localSessionId) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({'currentSessionId': localSessionId});
      }

      currentUser = user;
      update();
      MessagingBootstrap.startIfLoggedIn();
      _startAttendanceAutoIfEmployer();
      await PushNotificationService.instance.bindToUser(user.id);
      if (user.role == 'candidate') {
        unawaited(AlarmManagerService.instance.syncAutomaticAlarms());
      }
      await PushNavigationHandler.processPendingIfAny();
      _listenToSession(user.id);
      unawaited(cleanupDuplicateGroups());
    }
  }

  void _startAttendanceAutoIfEmployer() {
    if (currentUser?.role == 'employer') {
      AttendanceAutoNotifyService.instance.startEmployerPolling();
    } else {
      AttendanceAutoNotifyService.instance.stopEmployerPolling();
    }
  }

  Future<void> cleanupDuplicateGroups() async {
    return;
  }

  Future<UserModel> login(String email, String password) async {
    final user = await _authService.loginWithEmailPassword(email, password);
    return await _checkAndSetSession(user);
  }

  Future<UserModel> loginWithGoogle() async {
    final user = await _authService.loginWithGoogle();
    return await _checkAndSetSession(user);
  }

  Future<UserModel> loginWithFacebook() async {
    final user = await _authService.loginWithFacebook();
    return await _checkAndSetSession(user);
  }

  Future<UserModel> registerWithGoogle({
    required String role,
    String? firstName,
    String? lastName,
    String? username,
    String? phone,
    String? companyName,
    String? companyAddress,
  }) async {
    final user = await _authService.registerWithGoogle(
      role: role,
      firstName: firstName,
      lastName: lastName,
      username: username,
      phone: phone,
      companyName: companyName,
      companyAddress: companyAddress,
    );
    return await _checkAndSetSession(user);
  }

  Future<UserModel> registerWithFacebook({
    required String role,
    String? firstName,
    String? lastName,
    String? username,
    String? phone,
    String? companyName,
    String? companyAddress,
  }) async {
    final user = await _authService.registerWithFacebook(
      role: role,
      firstName: firstName,
      lastName: lastName,
      username: username,
      phone: phone,
      companyName: companyName,
      companyAddress: companyAddress,
    );
    return await _checkAndSetSession(user);
  }

  Future<UserModel> _checkAndSetSession(UserModel user) async {
    final docSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .get();
    final data = docSnap.data();
    final remoteSessionId = data?['currentSessionId'] as String?;
    final localSessionId = await PreferencesHelper.getOrCreateDeviceId();

    if (remoteSessionId != null &&
        remoteSessionId.isNotEmpty &&
        remoteSessionId != localSessionId) {
      // Báo hiệu thiết bị cũ rằng có thiết bị mới đăng nhập
      await FirebaseFirestore.instance.collection('users').doc(user.id).update({
        'lastLoginAttempt': DateTime.now().millisecondsSinceEpoch,
      });
    }

    currentUser = user;
    update();
    unawaited(cleanupDuplicateGroups());

    MessagingBootstrap.startIfLoggedIn();
    _startAttendanceAutoIfEmployer();
    await PushNotificationService.instance.bindToUser(user.id);
    if (user.role == 'candidate') {
      unawaited(AlarmManagerService.instance.syncAutomaticAlarms());
    }
    await PushNavigationHandler.processPendingIfAny();
    await FirebaseFirestore.instance.collection('users').doc(user.id).update({
      'currentSessionId': localSessionId,
    });
    _listenToSession(user.id);

    return user;
  }

  Future<void> logout() async {
    final uid = currentUser?.id;
    await PreferencesHelper.saveRememberMe(false, '');
    if (uid != null && uid.isNotEmpty) {
      await PushNotificationService.instance.unbindUser(uid);
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'currentSessionId': '',
        });
      } catch (_) {}
    }
    await _authService.logout();
    currentUser = null;
    MessagingBootstrap.stop();
    AttendanceAutoNotifyService.instance.stopEmployerPolling();
    _userSubscription?.cancel();
    _userSubscription = null;
    
    // Clear state
    Get.delete<EmployerProfileController>(force: true);
    Get.delete<JobPostController>(force: true);
    Get.delete<EmployerNotificationController>(force: true);
    Get.delete<EmployerHomeController>(force: true);
    Get.delete<MessagingController>(force: true);
    
    update();
  }

  int? _lastSeenAttempt;

  void _listenToSession(String uid) {
    _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null) {
              final remoteSessionId = data['currentSessionId'] as String?;
              final localSessionId =
                  await PreferencesHelper.getOrCreateDeviceId();

              if (remoteSessionId != null &&
                  remoteSessionId.isNotEmpty &&
                  remoteSessionId != localSessionId) {
                // Phiên đã bị thiết bị khác chiếm
                _userSubscription?.cancel();
                await _authService.logout();
                currentUser = null;
                MessagingBootstrap.stop();
                AttendanceAutoNotifyService.instance.stopEmployerPolling();
                update();

                Get.offAllNamed(AppRoutes.onboarding);
                Get.snackbar(
                  'Cảnh báo bảo mật',
                  'Tài khoản của bạn đã được đăng nhập ở thiết bị khác.',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 5),
                );
                return;
              }

              final attempt = data['lastLoginAttempt'] as int?;
              if (attempt != null) {
                if (_lastSeenAttempt != null && attempt > _lastSeenAttempt!) {
                  _showLoginAttemptWarning();
                }
                _lastSeenAttempt = attempt;
              }

              if (currentUser != null) {
                final mutableData = Map<String, dynamic>.from(data);
                mutableData['uid'] = uid;
                currentUser = UserModel.fromMap(mutableData);
                update();
              }
            }
          }
        });
  }

  void _showLoginAttemptWarning() {
    Get.snackbar(
      'Cảnh báo bảo mật',
      'Có thiết bị khác đang cố gắng đăng nhập vào tài khoản của bạn.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }
}
