import '../data/services/login_auth_service.dart';
import '../data/models/user_model.dart';
import 'package:get/get.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  UserModel? currentUser;

  Future<void> login(String email, String password) async {
    UserModel user = await _authService.loginWithEmailPassword(email, password);
    currentUser = user;
    Get.back(result: true);
  }

  Future<void> logout() async {
    await _authService.logout();
    currentUser = null;
    update();
  }
}
