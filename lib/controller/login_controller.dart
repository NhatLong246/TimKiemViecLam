import '../data/services/login_auth_service.dart';
import '../data/models/user_model.dart';
import 'package:get/get.dart';

class AuthController extends GetxController {
  final LoginAuthService _authService = LoginAuthService();
  UserModel? currentUser;

  Future<UserModel> login(String email, String password) async {
    final user = await _authService.loginWithEmailPassword(email, password);
    currentUser = user;
    update();
    return user;
  }

  Future<UserModel> loginWithGoogle() async {
    final user = await _authService.loginWithGoogle();
    currentUser = user;
    update();
    return user;
  }

  Future<UserModel> loginWithFacebook() async {
    final user = await _authService.loginWithFacebook();
    currentUser = user;
    update();
    return user;
  }

  Future<void> logout() async {
    await _authService.logout();
    currentUser = null;
    update();
  }
}
