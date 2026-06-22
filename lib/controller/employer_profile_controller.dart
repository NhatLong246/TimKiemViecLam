import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/user_model.dart';
import '../data/services/employer_profile_service.dart';
import '../data/services/profanity_filter_service.dart';
import '../controller/login_controller.dart';

enum EmployerDocumentType { businessLicense, taxCode, other }

class EmployerProfileController extends GetxController {
  final EmployerProfileService _service = EmployerProfileService();

  final Rx<UserModel?> profile = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isUploadingBusinessLicenses = false.obs;
  final RxBool isUploadingTaxCodeDocuments = false.obs;
  final RxBool isUploadingOtherDocuments = false.obs;

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
      if (ProfanityFilterService.containsProfanity('$firstName $lastName')) {
        throw Exception('Họ tên chứa từ ngữ không phù hợp.');
      }
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
      final authCtrl = Get.find<AuthController>();
      if (authCtrl.currentUser != null) {
        authCtrl.currentUser = authCtrl.currentUser!.copyWith(
          firstName: firstName ?? authCtrl.currentUser!.firstName,
          lastName: lastName ?? authCtrl.currentUser!.lastName,
          phone: phone ?? authCtrl.currentUser!.phone,
          gender: gender ?? authCtrl.currentUser!.gender,
          dateOfBirth: dateOfBirth ?? authCtrl.currentUser!.dateOfBirth,
          cccd: cccd ?? authCtrl.currentUser!.cccd,
          cccdImageUrl: cccdImageUrl ?? authCtrl.currentUser!.cccdImageUrl,
          cccdBackImageUrl:
              cccdBackImageUrl ?? authCtrl.currentUser!.cccdBackImageUrl,
        );
        authCtrl.update();
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

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'avatarBase64': b64,
      });

      profile.value = profile.value?.copyWith(avatarBase64: b64);

      // Cập nhật AuthController để UI toàn app phản ánh ngay
      final authCtrl = Get.find<AuthController>();
      if (authCtrl.currentUser != null) {
        authCtrl.currentUser = authCtrl.currentUser!.copyWith(
          avatarBase64: b64,
        );
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF7B1FA2),
              ),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(Get.context!, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: Color(0xFF1565C0),
              ),
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
      final url = await _service.uploadImage(file, 'users/$uid/cccd_$side.jpg');
      return url;
    } catch (e) {
      _showError('Tải ảnh CCCD thất bại: ${e.toString()}');
      return null;
    }
  }

  Future<void> pickAndUploadDocumentImages({
    required EmployerDocumentType type,
  }) async {
    final uploading = _uploadState(type);
    if (uploading.value) return;

    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 78,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (picked.isEmpty) return;

      uploading.value = true;
      final urls = await Future.wait(
        picked.map(
          (image) => _service.uploadImage(
            File(image.path),
            'users/${FirebaseAuth.instance.currentUser!.uid}/documents',
          ),
        ),
      );
      final current = _documentUrls(profile.value, type);
      final merged = <String>{...current, ...urls}.toList(growable: false);
      await _saveDocumentUrls(type: type, urls: merged);
      _showSuccess('Đã tải lên ${picked.length} ảnh ${_documentLabel(type)}');
    } catch (e) {
      _showError('Không thể tải ảnh tài liệu: ${e.toString()}');
    } finally {
      uploading.value = false;
    }
  }

  Future<void> removeDocumentImage({
    required EmployerDocumentType type,
    required String url,
  }) async {
    try {
      final current = _documentUrls(profile.value, type);
      final next = current.where((item) => item != url).toList(growable: false);
      await _saveDocumentUrls(type: type, urls: next);
      _showSuccess('Đã xóa ảnh khỏi hồ sơ');
    } catch (e) {
      _showError('Không thể xóa ảnh: ${e.toString()}');
    }
  }

  Future<void> _saveDocumentUrls({
    required EmployerDocumentType type,
    required List<String> urls,
  }) async {
    final field = switch (type) {
      EmployerDocumentType.businessLicense => 'businessLicenseImageUrls',
      EmployerDocumentType.taxCode => 'taxCodeImageUrls',
      EmployerDocumentType.other => 'otherDocumentImageUrls',
    };
    await _service.updateFields({field: urls});

    final currentProfile = profile.value;
    if (currentProfile != null) {
      profile.value = currentProfile.copyWith(
        businessLicenseImageUrls: type == EmployerDocumentType.businessLicense
            ? urls
            : currentProfile.businessLicenseImageUrls,
        taxCodeImageUrls: type == EmployerDocumentType.taxCode
            ? urls
            : currentProfile.taxCodeImageUrls,
        otherDocumentImageUrls: type == EmployerDocumentType.other
            ? urls
            : currentProfile.otherDocumentImageUrls,
      );
    }

    final authCtrl = Get.find<AuthController>();
    final currentUser = authCtrl.currentUser;
    if (currentUser != null) {
      authCtrl.currentUser = currentUser.copyWith(
        businessLicenseImageUrls: type == EmployerDocumentType.businessLicense
            ? urls
            : currentUser.businessLicenseImageUrls,
        taxCodeImageUrls: type == EmployerDocumentType.taxCode
            ? urls
            : currentUser.taxCodeImageUrls,
        otherDocumentImageUrls: type == EmployerDocumentType.other
            ? urls
            : currentUser.otherDocumentImageUrls,
      );
      authCtrl.update();
    }
  }

  RxBool _uploadState(EmployerDocumentType type) {
    return switch (type) {
      EmployerDocumentType.businessLicense => isUploadingBusinessLicenses,
      EmployerDocumentType.taxCode => isUploadingTaxCodeDocuments,
      EmployerDocumentType.other => isUploadingOtherDocuments,
    };
  }

  List<String> _documentUrls(UserModel? user, EmployerDocumentType type) {
    if (user == null) return const [];
    return switch (type) {
      EmployerDocumentType.businessLicense => user.businessLicenseImageUrls,
      EmployerDocumentType.taxCode => user.taxCodeImageUrls,
      EmployerDocumentType.other => user.otherDocumentImageUrls,
    };
  }

  String _documentLabel(EmployerDocumentType type) {
    return switch (type) {
      EmployerDocumentType.businessLicense => 'giấy phép kinh doanh',
      EmployerDocumentType.taxCode => 'mã số thuế',
      EmployerDocumentType.other => 'giấy tờ khác',
    };
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
      if (ProfanityFilterService.containsProfanity('$companyName $companyAddress $companyDescription')) {
        throw Exception('Thông tin chứa từ ngữ không phù hợp.');
      }
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
          companyDescription:
              companyDescription ?? profile.value!.companyDescription,
        );
      }
      final authCtrl = Get.find<AuthController>();
      if (authCtrl.currentUser != null) {
        authCtrl.currentUser = authCtrl.currentUser!.copyWith(
          companyName: companyName ?? authCtrl.currentUser!.companyName,
          companyAddress:
              companyAddress ?? authCtrl.currentUser!.companyAddress,
          companyPhone: companyPhone ?? authCtrl.currentUser!.companyPhone,
          companyWebsite:
              companyWebsite ?? authCtrl.currentUser!.companyWebsite,
          companyTaxCode:
              companyTaxCode ?? authCtrl.currentUser!.companyTaxCode,
          companySize: companySize ?? authCtrl.currentUser!.companySize,
          businessType: businessType ?? authCtrl.currentUser!.businessType,
          companyDescription:
              companyDescription ?? authCtrl.currentUser!.companyDescription,
        );
        authCtrl.update();
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
