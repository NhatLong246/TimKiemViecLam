import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/login_auth_service.dart';
import '../data/models/user_model.dart';
import '../utils/preferences_helper.dart';
import 'package:get/get.dart';
import '../data/services/attendance_auto_notify_service.dart';
import '../utils/messaging_bootstrap.dart';

class AuthController extends GetxController {
  final LoginAuthService _authService = LoginAuthService();
  UserModel? currentUser;
  bool _isPreparingSession = false;

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
    currentUser = user;
    update();
    MessagingBootstrap.startIfLoggedIn();
    _startAttendanceAutoIfEmployer();
    return user;
  }

  Future<UserModel> loginWithGoogle() async {
    final user = await _authService.loginWithGoogle();
    currentUser = user;
    update();
    MessagingBootstrap.startIfLoggedIn();
    _startAttendanceAutoIfEmployer();
    return user;
  }

  Future<UserModel> loginWithFacebook() async {
    final user = await _authService.loginWithFacebook();
    currentUser = user;
    update();
    MessagingBootstrap.startIfLoggedIn();
    _startAttendanceAutoIfEmployer();
    return user;
  }

  Future<void> logout() async {
    await PreferencesHelper.saveRememberMe(false, '');
    await _authService.logout();
    currentUser = null;
    MessagingBootstrap.stop();
    AttendanceAutoNotifyService.instance.stopEmployerPolling();
    update();
  }
}
