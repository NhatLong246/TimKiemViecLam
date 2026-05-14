import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/user_model.dart';
import '../data/services/employer_profile_service.dart';
import '../controller/login_controller.dart';

class EmployerProfileController extends GetxController {
  final EmployerProfileService _service = EmployerProfileService();

  final Rx<UserModel?> profile = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      isLoading.value = true;
      final p = await _service.fetchProfile();
      profile.value = p;
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể tải hồ sơ: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Cập nhật thông tin cá nhân
  Future<bool> savePersonalInfo({
    String? firstName,
    String? lastName,
    String? phone,
    String? gender,
    DateTime? dateOfBirth,
    String? cccd,
    String? cccdImageUrl,
    String? cccdBackImageUrl,
  }) async {
    try {
      isSaving.value = true;
      await _service.updatePersonalInfo(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        gender: gender,
        dateOfBirth: dateOfBirth,
        cccd: cccd,
        cccdImageUrl: cccdImageUrl,
        cccdBackImageUrl: cccdBackImageUrl,
      );
      // Cập nhật local state
      if (profile.value != null) {
        profile.value = profile.value!.copyWith(
          firstName: firstName ?? profile.value!.firstName,
          lastName: lastName ?? profile.value!.lastName,
          phone: phone ?? profile.value!.phone,
          gender: gender ?? profile.value!.gender,
          dateOfBirth: dateOfBirth ?? profile.value!.dateOfBirth,
          cccd: cccd ?? profile.value!.cccd,
          cccdImageUrl: cccdImageUrl ?? profile.value!.cccdImageUrl,
          cccdBackImageUrl: cccdBackImageUrl ?? profile.value!.cccdBackImageUrl,
        );
      }
      _showSuccess('Cập nhật thông tin cá nhân thành công');
      return true;
    } catch (e) {
      _showError('Cập nhật thất bại: ${e.toString()}');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Upload ảnh đại diện từ thư viện ảnh
  Future<void> uploadAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      isSaving.value = true;
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final url = await _service.uploadImage(
        File(picked.path),
        'users/$uid/avatar.jpg',
      );
      await _service.updateFields({'avatarUrl': url});
      profile.value = profile.value?.copyWith(avatarUrl: url);
      _showSuccess('Cập nhật ảnh đại diện thành công');
    } catch (e) {
      _showError('Tải ảnh thất bại: ${e.toString()}');
    } finally {
      isSaving.value = false;
    }
  }

  /// Upload ảnh CCCD (side: 'front' hoặc 'back'), trả về URL
  Future<String?> uploadCccdImage(File file, String side) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final url = await _service.uploadImage(
        file,
        'users/$uid/cccd_$side.jpg',
      );
      return url;
    } catch (e) {
      _showError('Tải ảnh CCCD thất bại: ${e.toString()}');
      return null;
    }
  }

  /// Cập nhật thông tin doanh nghiệp
  Future<bool> saveCompanyInfo({
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyWebsite,
    String? companyTaxCode,
    String? companySize,
    String? businessType,
    String? companyDescription,
  }) async {
    try {
      isSaving.value = true;
      await _service.updateCompanyInfo(
        companyName: companyName,
        companyAddress: companyAddress,
        companyPhone: companyPhone,
        companyWebsite: companyWebsite,
        companyTaxCode: companyTaxCode,
        companySize: companySize,
        businessType: businessType,
        companyDescription: companyDescription,
      );
      if (profile.value != null) {
        profile.value = profile.value!.copyWith(
          companyName: companyName ?? profile.value!.companyName,
          companyAddress: companyAddress ?? profile.value!.companyAddress,
          companyPhone: companyPhone ?? profile.value!.companyPhone,
          companyWebsite: companyWebsite ?? profile.value!.companyWebsite,
          companyTaxCode: companyTaxCode ?? profile.value!.companyTaxCode,
          companySize: companySize ?? profile.value!.companySize,
          businessType: businessType ?? profile.value!.businessType,
          companyDescription: companyDescription ?? profile.value!.companyDescription,
        );
      }
      _showSuccess('Cập nhật thông tin doanh nghiệp thành công');
      return true;
    } catch (e) {
      _showError('Cập nhật thất bại: ${e.toString()}');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Cập nhật một field đơn lẻ
  Future<bool> updateSingleField(String field, dynamic value) async {
    try {
      isSaving.value = true;
      await _service.updateFields({field: value});
      await loadProfile(); // reload để đồng bộ
      return true;
    } catch (e) {
      _showError('Cập nhật thất bại: ${e.toString()}');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  void _showSuccess(String msg) {
    Get.snackbar(
      'Thành công',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade100,
      colorText: Colors.green.shade800,
      duration: const Duration(seconds: 2),
    );
  }

  void _showError(String msg) {
    Get.snackbar(
      'Lỗi',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade100,
      colorText: Colors.red.shade800,
    );
  }

  Future<void> logout() async {
    final authController = Get.find<AuthController>();
    await authController.logout();
  }

  String formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}tr đ';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k đ';
    }
    return '${amount.toStringAsFixed(0)} đ';
  }
}
