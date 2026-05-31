import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../common/styles/app_colors.dart';
import '../../controller/login_controller.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/services/notification_service.dart';
import '../../routes/app_routes.dart';

/// Khiếu nại công việc / NTD sau khi đã hoàn thành (ứng viên).
class CandidateJobComplaintScreen extends StatefulWidget {
  const CandidateJobComplaintScreen({super.key});

  @override
  State<CandidateJobComplaintScreen> createState() =>
      _CandidateJobComplaintScreenState();
}

class _CandidateJobComplaintScreenState extends State<CandidateJobComplaintScreen> {
  final _auth = Get.find<AuthController>();
  final _descCtrl = TextEditingController();
  final _images = <String>[];
  bool _submitting = false;
  late GroupChatModel _group;

  @override
  void initState() {
    super.initState();
    _group = Get.arguments as GroupChatModel;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 4) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 55,
      maxWidth: 800,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 800 * 1024) {
      Get.snackbar('Ảnh quá lớn', 'Chọn ảnh nhỏ hơn 800KB');
      return;
    }
    setState(() => _images.add(base64Encode(bytes)));
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().length < 10) {
      Get.snackbar('Thiếu thông tin', 'Mô tả ít nhất 10 ký tự');
      return;
    }
    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('jobComplaints').add({
        'jobId': _group.jobId,
        'groupId': _group.groupId,
        'employerId': _group.employerId,
        'candidateId': _auth.currentUser?.id ?? '',
        'jobTitle': _group.jobTitle,
        'description': _descCtrl.text.trim(),
        'imageBase64s': _images,
        'status': 'pending',
        'complaintKind': 'candidate_active_job',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_group.employerId.isNotEmpty) {
        await NotificationService().create(
          recipientId: _group.employerId,
          type: 'complaint_received',
          title: 'Khiếu nại về công việc bạn đăng',
          body:
              'UV khiếu nại về tin "${_group.jobTitle}". Xem mục Về tin đăng.',
          data: {
            'groupId': _group.groupId,
            'jobId': _group.jobId,
          },
        );
      }

      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(10)
          .get();
      for (final a in admins.docs) {
        await NotificationService().create(
          recipientId: a.id,
          type: 'complaint_received',
          title: 'Khiếu nại công việc mới',
          body: 'UV khiếu nại về "${_group.jobTitle}".',
          data: {'groupId': _group.groupId, 'jobId': _group.jobId},
        );
      }

      Get.back();
      Get.snackbar(
        'Đã gửi',
        'Đã lưu vào Danh mục khiếu nại.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Get.toNamed(AppRoutes.complaintsCatalog, arguments: _group);
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.candidatePrimary,
        foregroundColor: Colors.white,
        title: const Text('Khiếu nại công việc'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _group.jobTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Nội dung khiếu nại *',
              hintText: 'Mô tả vấn đề sau khi hoàn thành công việc...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ..._images.map(
                (b) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(b),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Thêm ảnh'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.candidatePrimary,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_submitting ? 'Đang gửi...' : 'Gửi khiếu nại'),
          ),
        ],
      ),
    );
  }
}
