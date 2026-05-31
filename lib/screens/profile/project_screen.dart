import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/update_account_controller.dart';
import 'package:viecnow/data/models/candidate_profile_models.dart';
import 'profile_form_theme.dart';
import 'profile_pickers.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key, this.project});

  final ProjectModel? project;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _startDate = '';
  String _endDate = '';
  bool _saving = false;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    if (p != null) {
      _nameController.text = p.name;
      _descriptionController.text = p.description;
      _startDate = p.startDate;
      _endDate = p.endDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showProfileMonthYearPicker(context);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate.isEmpty || _endDate.isEmpty) {
      ProfileFormTheme.showSnack(
        context,
        'Vui lòng chọn ngày bắt đầu và kết thúc',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final ctrl = Get.put(UpdateAccountController());
      final model = ProjectModel(
        id: widget.project?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        description: _descriptionController.text.trim(),
      );
      if (_isEditing) {
        await ctrl.updateProject(model);
      } else {
        await ctrl.addProject(model);
      }
      if (!mounted) return;
      ProfileFormTheme.showSnack(
        context,
        _isEditing ? 'Đã cập nhật dự án' : 'Đã thêm dự án/ thành tựu',
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: ProfileFormTheme.buildAppBar(
        context,
        _isEditing ? 'Chỉnh sửa dự án' : 'Dự án/ thành tựu',
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileFormTheme.requiredLabel('Tên dự án/ thành tựu'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Vui lòng nhập tên dự án'
                    : null,
                decoration: ProfileFormTheme.fieldDecoration(hintText: 'Nhập tên dự án/ thành tựu',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileFormTheme.requiredLabel('Ngày bắt đầu'),
                        const SizedBox(height: 8),
                        ProfileFormTheme.dateField(value: _startDate,
                          placeholder: 'MM/YYYY',
                          onTap: () => _pickDate(true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileFormTheme.requiredLabel('Ngày kết thúc'),
                        const SizedBox(height: 8),
                        ProfileFormTheme.dateField(value: _endDate,
                          placeholder: 'MM/YYYY',
                          onTap: () => _pickDate(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ProfileFormTheme.requiredLabel('Mô tả chi tiết', required: false),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 8,
                decoration: ProfileFormTheme.fieldDecoration(hintText:
                      'Nhập mô tả vai trò trong dự án/ thành tựu này',
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
