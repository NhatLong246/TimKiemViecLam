import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/register_auth_service.dart';
import '../data/models/user_model.dart';
import '../data/services/profanity_filter_service.dart';

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
      if (ProfanityFilterService.containsProfanity('$firstName $lastName $username $companyName $companyAddress')) {
        return 'Thông tin đăng ký chứa từ ngữ không phù hợp.';
      }
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
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Email này đã được đăng ký. Vui lòng dùng email khác hoặc đăng nhập.';
        case 'invalid-email':
          return 'Địa chỉ email không hợp lệ.';
        case 'weak-password':
          return 'Mật khẩu quá yếu. Vui lòng chọn mật khẩu mạnh hơn.';
        case 'operation-not-allowed':
          return 'Phương thức đăng ký này chưa được kích hoạt.';
        default:
          return 'Đăng ký thất bại. Vui lòng thử lại.';
      }
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
