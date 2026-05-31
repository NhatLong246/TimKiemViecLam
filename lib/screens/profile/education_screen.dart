import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/update_account_controller.dart';
import 'package:viecnow/data/models/candidate_profile_models.dart';
import 'profile_form_theme.dart';
import 'profile_pickers.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key, this.education});

  final EducationModel? education;

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  static const _degreeOptions = [
    'Trung học phổ thông',
    'Trung cấp',
    'Cao đẳng',
    'Đại học',
    'Thạc sĩ',
    'Tiến sĩ',
    'Khác',
  ];

  final _formKey = GlobalKey<FormState>();
  final _schoolController = TextEditingController();
  final _majorController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _startYear = '';
  String _endYear = '';
  String _degree = '';
  bool _saving = false;

  bool get _isEditing => widget.education != null;

  @override
  void initState() {
    super.initState();
    final e = widget.education;
    if (e != null) {
      _schoolController.text = e.school;
      _majorController.text = e.major;
      _descriptionController.text = e.description;
      _startYear = e.startYear;
      _endYear = e.endYear;
      _degree = e.degree;
    }
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _majorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickYear(bool isStart) async {
    final picked = await showProfileYearPicker(context);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startYear = picked;
        } else {
          _endYear = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startYear.isEmpty || _endYear.isEmpty) {
      ProfileFormTheme.showSnack(
        context,
        'Vui lòng chọn năm bắt đầu và kết thúc',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final ctrl = Get.put(UpdateAccountController());
      final model = EducationModel(
        id: widget.education?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        school: _schoolController.text.trim(),
        startYear: _startYear,
        endYear: _endYear,
        major: _majorController.text.trim(),
        degree: _degree,
        description: _descriptionController.text.trim(),
      );
      if (_isEditing) {
        await ctrl.updateEducation(model);
      } else {
        await ctrl.addEducation(model);
      }
      if (!mounted) return;
      ProfileFormTheme.showSnack(
        context,
        _isEditing ? 'Đã cập nhật học vấn' : 'Đã thêm học vấn',
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ProfileFormTheme.buildAppBar(
        context,
        _isEditing ? 'Chỉnh sửa học vấn' : 'Trình độ học vấn',
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileFormTheme.requiredLabel('Tên trường học'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _schoolController,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Vui lòng nhập tên trường'
                    : null,
                decoration: ProfileFormTheme.fieldDecoration(
                  hintText: 'Nhập tên trường học',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileFormTheme.requiredLabel('Năm bắt đầu'),
                        const SizedBox(height: 8),
                        ProfileFormTheme.dateField(
                          value: _startYear,
                          placeholder: 'YYYY',
                          onTap: () => _pickYear(true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileFormTheme.requiredLabel('Năm kết thúc'),
                        const SizedBox(height: 8),
                        ProfileFormTheme.dateField(
                          value: _endYear,
                          placeholder: 'YYYY',
                          onTap: () => _pickYear(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ProfileFormTheme.requiredLabel('Ngành học', required: false),
              const SizedBox(height: 8),
              TextFormField(
                controller: _majorController,
                decoration: ProfileFormTheme.fieldDecoration(
                  hintText: 'Nhập ngành học',
                ),
              ),
              const SizedBox(height: 20),
              ProfileFormTheme.requiredLabel('Bằng cấp', required: false),
              const SizedBox(height: 8),
              ProfileFormTheme.selectField(
                value: _degree,
                placeholder: 'Chọn bằng cấp',
                onTap: () async {
                  final picked = await showProfileOptionSheet(
                    context,
                    title: 'Chọn bằng cấp',
                    options: _degreeOptions,
                    selected: _degree.isEmpty ? null : _degree,
                  );
                  if (picked != null) setState(() => _degree = picked);
                },
              ),
              const SizedBox(height: 20),
              ProfileFormTheme.requiredLabel('Mô tả chi tiết', required: false),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 8,
                decoration: ProfileFormTheme.fieldDecoration(
                  hintText: 'Nhập mô tả',
                  maxLines: 4,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ProfileFormTheme.saveBar(
        saving: _saving,
        enabled: true,
        onSave: _save,
      ),
    );
  }
}
