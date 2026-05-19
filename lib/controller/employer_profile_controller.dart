import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Upload ảnh đại diện — lưu dạng Base64 vào Firestore (không cần Firebase Storage)
  Future<void> uploadAvatar() async {
    try {
      final source = await _pickAvatarSource();
      if (source == null) return;

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 65,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (picked == null) return;

      final bytes = await File(picked.path).readAsBytes();
      if (bytes.length > 500 * 1024) {
        _showError('Ảnh quá lớn. Vui lòng chọn ảnh nhỏ hơn 500 KB.');
        return;
      }

      isSaving.value = true;
      final b64 = base64Encode(bytes);
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'avatarBase64': b64});

      profile.value = profile.value?.copyWith(avatarBase64: b64);

      // Cập nhật AuthController để UI toàn app phản ánh ngay
      final authCtrl = Get.find<AuthController>();
      if (authCtrl.currentUser != null) {
        authCtrl.currentUser =
            authCtrl.currentUser!.copyWith(avatarBase64: b64);
        authCtrl.update();
      }

      _showSuccess('Cập nhật ảnh đại diện thành công');
    } catch (e) {
      _showError('Tải ảnh thất bại: ${e.toString()}');
    } finally {
      isSaving.value = false;
    }
  }

  Future<ImageSource?> _pickAvatarSource() async {
    return showModalBottomSheet<ImageSource>(
      context: Get.context!,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFF7B1FA2)),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(Get.context!, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFF1565C0)),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(Get.context!, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
