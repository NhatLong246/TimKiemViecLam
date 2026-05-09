import '../data/services/register_auth_service.dart';
import '../data/models/user_model.dart';

class RegisterController {
  final RegisterAuthService _authService = RegisterAuthService();

  Future<String?> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String phone,
    required String password,
    required String role, // "candidate" | "employer"
    String? companyName,
    String? companyAddress,
  }) async {
    try {
      final UserModel userModel = UserModel(
        id: '',
        role: role,
        firstName: firstName,
        lastName: lastName,
        username: username,
        email: email,
        phone: phone,
        isVerified: false,
        isActive: true,
        companyName: companyName,
        companyAddress: companyAddress,
      );
      await _authService.registerUser(userModel: userModel, password: password);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
