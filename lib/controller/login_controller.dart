import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/login_auth_service.dart';
import '../data/models/user_model.dart';
import '../utils/preferences_helper.dart';
import 'package:get/get.dart';
import '../data/services/attendance_auto_notify_service.dart';
import '../data/services/push_notification_service.dart';
import '../utils/messaging_bootstrap.dart';
import '../utils/push_navigation_handler.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes/app_routes.dart';
class AuthController extends GetxController {
  final LoginAuthService _authService = LoginAuthService();
  UserModel? currentUser;
  bool _isPreparingSession = false;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  /// Mở app: chỉ giữ đăng nhập nếu đã tick **Ghi nhớ đăng nhập** lần trước.
  Future<void> prepareSessionOnStartup() async {
    if (_isPreparingSession) return;
    _isPreparingSession = true;
    try {
      await _prepareSessionOnStartupImpl().timeout(const Duration(seconds: 12));
    } catch (_) {
      currentUser = null;
      update();
    } finally {
      _isPreparingSession = false;
    }
  }

  Future<void> _prepareSessionOnStartupImpl() async {
    final rememberMe = await PreferencesHelper.getRememberMe();
    if (!rememberMe) {
      if (FirebaseAuth.instance.currentUser != null) {
        await _authService.logout();
      }
      currentUser = null;
      update();
      return;
    }

    final user = await _authService.restoreSessionFromFirebase();
    if (user != null) {
      currentUser = user;
      update();
      MessagingBootstrap.startIfLoggedIn();
      _startAttendanceAutoIfEmployer();
      await PushNotificationService.instance.bindToUser(user.id);
      await PushNavigationHandler.processPendingIfAny();
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      await PreferencesHelper.saveCurrentSessionId(sessionId);
      await FirebaseFirestore.instance.collection('users').doc(user.id).update({
        'currentSessionId': sessionId,
      });
      _listenToSession(user.id);
    }
  }

  void _startAttendanceAutoIfEmployer() {
    if (currentUser?.role == 'employer') {
      AttendanceAutoNotifyService.instance.startEmployerPolling();
    } else {
      AttendanceAutoNotifyService.instance.stopEmployerPolling();
    }
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

  Future<UserModel> _checkAndSetSession(UserModel user) async {
    final docSnap = await FirebaseFirestore.instance.collection('users').doc(user.id).get();
    final data = docSnap.data();
    final remoteSessionId = data?['currentSessionId'] as String?;
    final localSessionId = await PreferencesHelper.getCurrentSessionId();

    if (remoteSessionId != null && remoteSessionId.isNotEmpty && remoteSessionId != localSessionId) {
      await FirebaseFirestore.instance.collection('users').doc(user.id).update({
        'lastLoginAttempt': DateTime.now().millisecondsSinceEpoch,
      });

      final completer = Completer<bool>();
      Get.defaultDialog(
        title: 'Tài khoản đang đăng nhập',
        middleText: 'Tài khoản này đang được sử dụng ở thiết bị khác (hoặc bạn chưa đăng xuất trước khi xoá app). Bạn có muốn ép đăng nhập để gỡ kẹt không?',
        textConfirm: 'Ép đăng nhập',
        textCancel: 'Huỷ',
        confirmTextColor: Colors.white,
        barrierDismissible: false,
        onConfirm: () {
          Get.back();
          if (!completer.isCompleted) completer.complete(true);
        },
        onCancel: () {
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      final force = await completer.future;
      if (!force) {
        await _authService.logout();
        throw Exception('Tài khoản đang được đăng nhập trên một thiết bị khác. Không thể đăng nhập.');
      }
    }

    currentUser = user;
    update();
    MessagingBootstrap.startIfLoggedIn();
    _startAttendanceAutoIfEmployer();
    await PushNotificationService.instance.bindToUser(user.id);
    await PushNavigationHandler.processPendingIfAny();
    
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    await PreferencesHelper.saveCurrentSessionId(sessionId);
    await FirebaseFirestore.instance.collection('users').doc(user.id).update({
      'currentSessionId': sessionId,
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
    await PreferencesHelper.saveCurrentSessionId('');
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
          final attempt = data['lastLoginAttempt'] as int?;
          if (attempt != null) {
            if (_lastSeenAttempt != null && attempt > _lastSeenAttempt!) {
              _showLoginAttemptWarning();
            }
            _lastSeenAttempt = attempt;
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
