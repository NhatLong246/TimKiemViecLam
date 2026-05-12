import 'package:viecnow/controller/login_controller.dart';
import '../data/services/update_account_service.dart';
import 'package:get/get.dart';

class UpdateAccountController extends GetxController {
  final UpdateAccountService _service = UpdateAccountService();

  Future<void> changeName(String fullName) async {
    final authController = Get.find<AuthController>();
    final user = authController.currentUser;
    if (user == null) return;
    // Tách firstName + lastName
    List<String> parts = fullName.trim().split(' ');
    String firstName = parts.first;
    String lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    // Update Firestore
    await _service.updateName(
      userId: user.id,
      firstName: firstName,
      lastName: lastName,
    );
    // 2Update local currentUser
    authController.currentUser = user.copyWith(
      firstName: firstName,
      lastName: lastName,
    );
    authController.update(); // nếu dùng GetBuilder
  }

  Future<void> updateUsername(String username) async {
    await _service.updateUsername(username);
  }

  Future<void> updateEmail(String email) async {
    await _service.updateEmail(email);
  }

  Future<void> syncEmailAfterVerification() async {
    await _service.syncEmailAfterVerification();
  }

  Future<void> updateGender(String gender) async {
    await _service.updateGender(gender);
  }

  Future<void> updateDateOfBirth(DateTime date) async {
    await _service.updateDateOfBirth(date);
  }

  Future<void> updatePhone(String phone) async {
    await _service.updatePhone(phone);
  }

  Stream getUserData() {
    return _service.getUserData();
  }
}
