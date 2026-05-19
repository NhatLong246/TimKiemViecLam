import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/update_account_controller.dart';
import 'package:viecnow/data/models/candidate_profile_models.dart';
import 'profile_form_theme.dart';
import 'profile_pickers.dart';

class ForeignLanguageScreen extends StatefulWidget {
  const ForeignLanguageScreen({super.key, this.language});

  final LanguageModel? language;

  @override
  State<ForeignLanguageScreen> createState() => _ForeignLanguageScreenState();
}

class _ForeignLanguageScreenState extends State<ForeignLanguageScreen> {
  static const _languageOptions = [
    'Tiếng Anh',
    'Tiếng Trung',
    'Tiếng Nhật',
    'Tiếng Hàn',
    'Tiếng Pháp',
    'Tiếng Đức',
    'Tiếng Nga',
    'Tiếng Thái',
    'Tiếng Tây Ban Nha',
    'Tiếng Bồ Đào Nha',
    'Tiếng Ý',
    'Tiếng Ả Rập',
    'Khác',
  ];

  static const _levelOptions = ['Sơ cấp', 'Trung cấp', 'Cao cấp'];

  String? _language;
  String? _level;
  bool _saving = false;

  bool get _isEditing => widget.language != null;

  bool get _canSave =>
      _language != null &&
      _language!.isNotEmpty &&
      _level != null &&
      _level!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final item = widget.language;
    if (item != null) {
      _language = item.language;
      _level = item.level;
    } else {
      _level = _levelOptions.first;
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final ctrl = Get.find<UpdateAccountController>();
      final model = LanguageModel(
        id: widget.language?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        language: _language!,
        level: _level!,
      );
      if (_isEditing) {
        await ctrl.updateLanguage(model);
      } else {
        await ctrl.addLanguage(model);
      }
      if (!mounted) return;
      ProfileFormTheme.showSnack(
        context,
        _isEditing ? 'Đã cập nhật ngoại ngữ' : 'Đã thêm ngoại ngữ',
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
      appBar: ProfileFormTheme.buildAppBar(context, 'Ngoại ngữ'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileFormTheme.requiredLabel('Tên ngoại ngữ'),
            const SizedBox(height: 8),
            ProfileFormTheme.selectField(
              value: _language ?? '',
              placeholder: 'Chọn ngoại ngữ',
              onTap: () async {
                final picked = await showProfileOptionSheet(
                  context,
                  title: 'Chọn ngoại ngữ',
                  options: _languageOptions,
                  selected: _language,
                );
                if (picked != null) setState(() => _language = picked);
              },
            ),
            const SizedBox(height: 24),
            ProfileFormTheme.requiredLabel('Mức độ'),
            const SizedBox(height: 10),
            ProfileFormTheme.levelPills(
              options: _levelOptions,
              selected: _level,
              onSelect: (v) => setState(() => _level = v),
            ),
          ],
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
