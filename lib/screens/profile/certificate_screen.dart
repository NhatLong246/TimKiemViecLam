import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:viecnow/controller/update_account_controller.dart';
import 'package:viecnow/data/models/candidate_profile_models.dart';
import 'profile_form_theme.dart';

class CertificateScreen extends StatefulWidget {
  const CertificateScreen({super.key, this.certificate});

  final CertificateModel? certificate;

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  static const int _maxBytes = 5 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  String? _imageUrl;
  File? _localImage;
  bool _saving = false;

  bool get _isEditing => widget.certificate != null;

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final c = widget.certificate;
    if (c != null) {
      _nameController.text = c.name;
      _imageUrl = c.imageUrl;
    }
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final file = File(picked.path);
    final size = await file.length();
    if (size > _maxBytes) {
      if (mounted) {
        ProfileFormTheme.showSnack(
          context,
          'Ảnh tối đa 5MB',
          error: true,
        );
      }
      return;
    }
    setState(() {
      _localImage = file;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final ctrl = Get.find<UpdateAccountController>();
      final id = widget.certificate?.id ??
          DateTime.now().millisecondsSinceEpoch.toString();

      String? url = _imageUrl;
      if (_localImage != null) {
        url = await ctrl.uploadCertificateImage(_localImage!, id);
      }

      final model = CertificateModel(
        id: id,
        name: _nameController.text.trim(),
        imageUrl: url,
      );

      if (_isEditing) {
        await ctrl.updateCertificate(model);
      } else {
        await ctrl.addCertificate(model);
      }
      if (!mounted) return;
      ProfileFormTheme.showSnack(
        context,
        _isEditing ? 'Đã cập nhật chứng chỉ' : 'Đã thêm chứng chỉ/ bằng cấp',
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ProfileFormTheme.showSnack(
          context,
          'Không thể lưu. Vui lòng thử lại.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _localImage != null
        ? FileImage(_localImage!)
        : (_imageUrl != null && _imageUrl!.isNotEmpty)
            ? NetworkImage(_imageUrl!) as ImageProvider
            : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ProfileFormTheme.buildAppBar(
        context,
        _isEditing ? 'Chỉnh sửa chứng chỉ' : 'Chứng chỉ/ Bằng cấp',
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileFormTheme.requiredLabel('Tên chứng chỉ/ bằng cấp'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Vui lòng nhập tên chứng chỉ'
                    : null,
                decoration: ProfileFormTheme.fieldDecoration(
                  hintText: 'Nhập tên chứng chỉ/ bằng cấp',
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: preview != null ? 180 : 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ProfileFormTheme.primary.withValues(alpha: 0.5),
                      width: 1.2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: preview != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image(
                            image: preview,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.file_upload_outlined,
                              color: ProfileFormTheme.primary,
                              size: 28,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tải ảnh lên',
                              style: TextStyle(
                                color: ProfileFormTheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hỗ trợ định dạng PNG, JPG, JPEG. Tối đa 5MB',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ProfileFormTheme.saveBar(
        saving: _saving,
        enabled: _canSave,
        onSave: _save,
      ),
    );
  }
}
