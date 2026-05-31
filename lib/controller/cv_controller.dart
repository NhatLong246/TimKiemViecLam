import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:viecnow/data/services/cv_service.dart';

class CvController extends GetxController {
  final CvService _service = CvService();

  final RxBool isUploading = false.obs;
  final RxBool isRemoving = false.obs;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get userStream =>
      _service.watchUser();

  Future<void> pickAndUploadCv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final path = file.path;
    if (path == null || path.isEmpty) {
      Get.snackbar('Lỗi', 'Không đọc được file đã chọn');
      return;
    }

    try {
      isUploading.value = true;
      await _service.uploadCvFile(
        File(path),
        fileName: file.name,
      );
      Get.snackbar(
        'Thành công',
        'Đã tải CV lên hồ sơ',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.primaryContainer,
      );
    } catch (e) {
      Get.snackbar(
        'Không tải được CV',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> removeCv() async {
    try {
      isRemoving.value = true;
      await _service.removeCvFile();
      Get.snackbar('Đã xóa', 'File CV đã được gỡ khỏi hồ sơ');
    } catch (e) {
      Get.snackbar('Lỗi', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isRemoving.value = false;
    }
  }
}
