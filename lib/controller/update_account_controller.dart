import 'dart:io';

import 'package:viecnow/controller/login_controller.dart';
import '../data/models/candidate_profile_models.dart';
import '../data/models/job_criteria_model.dart';
import '../data/models/work_experience_model.dart';
import '../data/services/candidate_profile_service.dart';
import '../data/services/update_account_service.dart';
import 'package:get/get.dart';

class UpdateAccountController extends GetxController {
  final UpdateAccountService _service = UpdateAccountService();
  final CandidateProfileService _profileService = CandidateProfileService();

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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Stream? _userDataStream;
  Stream getUserData() {
    _userDataStream ??= _service.getUserData();
    return _userDataStream!;
  }

  Future<void> refreshProfile() async {
    final user = await _service
        .refreshCurrentUser()
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception(
            'Tải hồ sơ quá lâu. Kiểm tra mạng và thử lại.',
          ),
        );
    if (user == null) {
      throw Exception('Không tải được hồ sơ. Vui lòng đăng nhập lại.');
    }
    final authController = Get.find<AuthController>();
    authController.currentUser = user;
    authController.update();
    update();
  }

  Future<void> addWorkExperience({
    required String company,
    required String position,
    required String description,
    required String startDate,
    String? endDate,
    required bool currentlyWorking,
  }) async {
    final experience = WorkExperienceModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      company: company.trim(),
      position: position.trim(),
      description: description.trim(),
      startDate: startDate,
      endDate: currentlyWorking ? null : endDate,
      currentlyWorking: currentlyWorking,
    );
    await _service.addWorkExperience(experience);
  }

  Future<void> updateWorkExperience({
    required String id,
    required String company,
    required String position,
    required String description,
    required String startDate,
    String? endDate,
    required bool currentlyWorking,
  }) async {
    final experience = WorkExperienceModel(
      id: id,
      company: company.trim(),
      position: position.trim(),
      description: description.trim(),
      startDate: startDate,
      endDate: currentlyWorking ? null : endDate,
      currentlyWorking: currentlyWorking,
    );
    await _service.updateWorkExperience(experience);
  }

  Future<void> removeWorkExperience(String experienceId) async {
    await _service.removeWorkExperience(experienceId);
  }

  Future<void> declareNoWorkExperience() async {
    await _service.declareNoWorkExperience();
  }

  Future<void> updateAllowEmployerDiscovery(bool value) async {
    await _service.setAllowEmployerDiscovery(value);
  }

  Future<void> saveJobCriteria(JobCriteriaModel criteria) async {
    await _service.saveJobCriteria(criteria);
  }

  Future<void> clearJobCriteria() async {
    await _service.clearJobCriteria();
  }

  Future<void> updateJobStatus({
    required String currentWorkStatus,
    required String jobSearchStatus,
  }) async {
    await _service.updateJobStatus(
      currentWorkStatus: currentWorkStatus,
      jobSearchStatus: jobSearchStatus,
    );
  }

  Future<String> uploadAvatar(File file) async {
    final url = await _service.uploadAvatar(file);
    final authController = Get.find<AuthController>();
    final user = authController.currentUser;
    if (user != null) {
      authController.currentUser = user.copyWith(avatarUrl: url);
      authController.update();
    }
    return url;
  }

  Future<void> saveSelfIntroduction(String text) async {
    await _profileService.saveSelfIntroduction(text);
  }

  Future<void> saveSkills(List<String> skills) async {
    await _profileService.saveSkills(skills);
  }

  Future<void> addEducation(EducationModel item) async {
    await _profileService.addEducation(item);
  }

  Future<void> updateEducation(EducationModel item) async {
    await _profileService.updateEducation(item);
  }

  Future<void> removeEducation(String id) async {
    await _profileService.removeEducation(id);
  }

  Future<void> addProject(ProjectModel item) async {
    await _profileService.addProject(item);
  }

  Future<void> updateProject(ProjectModel item) async {
    await _profileService.updateProject(item);
  }

  Future<void> removeProject(String id) async {
    await _profileService.removeProject(id);
  }

  Future<void> addLanguage(LanguageModel item) async {
    await _profileService.addLanguage(item);
  }

  Future<void> updateLanguage(LanguageModel item) async {
    await _profileService.updateLanguage(item);
  }

  Future<void> removeLanguage(String id) async {
    await _profileService.removeLanguage(id);
  }

  Future<void> addCertificate(CertificateModel item) async {
    await _profileService.addCertificate(item);
  }

  Future<void> updateCertificate(CertificateModel item) async {
    await _profileService.updateCertificate(item);
  }

  Future<void> removeCertificate(String id) async {
    await _profileService.removeCertificate(id);
  }

  Future<String> uploadCertificateImage(File file, String certificateId) async {
    return _profileService.uploadCertificateImage(file, certificateId);
  }
}
