import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/update_account_controller.dart';
import 'package:viecnow/data/constants/language_proficiency_levels.dart';
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
  /// `ielts` | `toeic` — chọn trước mới hiện ô nhập điểm.
  static const _certIelts = 'ielts';
  static const _certToeic = 'toeic';

  String? _language;
  String? _cefrLevel;
  String? _selectedCert;
  final _ieltsController = TextEditingController();
  final _toeicController = TextEditingController();
  bool _saving = false;

  bool get _isEditing => widget.language != null;

  bool get _isEnglish => LanguageProficiencyLevels.isEnglish(_language);

  String? get _resolvedLevel {
    if (_language == null || _language!.isEmpty) return null;
    if (_isEnglish) {
      return LanguageProficiencyLevels.composeEnglishLevel(
        cefr: _cefrLevel,
        ieltsScore: _selectedCert == _certIelts ? _ieltsController.text : null,
        toeicScore: _selectedCert == _certToeic ? _toeicController.text : null,
      );
    }
    return _cefrLevel;
  }

  List<String> get _levelOptions => LanguageProficiencyLevels.optionsFor(
        _language,
        currentLevel: _isEnglish ? _cefrLevel : _cefrLevel,
      );

  bool get _canSave =>
      _language != null &&
      _language!.isNotEmpty &&
      (_resolvedLevel?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    final item = widget.language;
    if (item == null) return;

    _language = item.language;
    if (LanguageProficiencyLevels.isEnglish(item.language)) {
      final parts = LanguageProficiencyLevels.parseEnglishLevel(item.level);
      _cefrLevel = parts.cefr;
      final ielts = parts.ieltsScore?.trim() ?? '';
      final toeic = parts.toeicScore?.trim() ?? '';
      if (ielts.isNotEmpty) {
        _selectedCert = _certIelts;
        _ieltsController.text = ielts;
      } else if (toeic.isNotEmpty) {
        _selectedCert = _certToeic;
        _toeicController.text = toeic;
      } else if (parts.other != null && _cefrLevel == null) {
        _cefrLevel = parts.other;
      }
    } else {
      _cefrLevel = item.level;
    }
  }

  @override
  void dispose() {
    _ieltsController.dispose();
    _toeicController.dispose();
    super.dispose();
  }

  void _onLanguagePicked(String picked) {
    setState(() {
      _language = picked;
      _selectedCert = null;
      _ieltsController.clear();
      _toeicController.clear();

      if (LanguageProficiencyLevels.isEnglish(picked)) {
        if (_cefrLevel != null &&
            !LanguageProficiencyLevels.englishCefrLevels.contains(_cefrLevel)) {
          _cefrLevel = null;
        }
        return;
      }

      final levels = LanguageProficiencyLevels.forLanguage(picked);
      if (_cefrLevel != null && levels.contains(_cefrLevel)) return;

      final legacy = _cefrLevel != null
          ? LanguageProficiencyLevels.mapLegacyLevel(picked, _cefrLevel!)
          : null;
      _cefrLevel = legacy ?? (levels.isNotEmpty ? levels.first : null);
    });
  }

  void _selectCefr(String v) {
    setState(() {
      _cefrLevel = v;
      _selectedCert = null;
      _ieltsController.clear();
      _toeicController.clear();
    });
  }

  void _selectCert(String cert) {
    setState(() {
      _selectedCert = cert;
      _cefrLevel = null;
      if (cert == _certIelts) {
        _toeicController.clear();
      } else {
        _ieltsController.clear();
      }
    });
  }

  Future<void> _save() async {
    final level = _resolvedLevel;
    if (level == null || level.isEmpty) return;

    setState(() => _saving = true);
    try {
      final ctrl = Get.put(UpdateAccountController());
      final model = LanguageModel(
        id: widget.language?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        language: _language!,
        level: level,
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
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ProfileFormTheme.showSnack(
          context,
          msg.isEmpty ? 'Không thể lưu. Vui lòng thử lại.' : msg,
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelHint = _language == null
        ? 'Chọn ngôn ngữ trước'
        : LanguageProficiencyLevels.levelHintFor(_language!);

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
                  options: LanguageProficiencyLevels.languageOptions,
                  selected: _language,
                );
                if (picked != null) _onLanguagePicked(picked);
              },
            ),
            const SizedBox(height: 24),
            ProfileFormTheme.requiredLabel('Mức độ'),
            if (levelHint.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                levelHint,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 10),
            _buildLevelSelector(),
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

  Widget _buildLevelSelector() {
    if (_language == null || _language!.isEmpty) {
      return _placeholderBox('Chọn ngôn ngữ trước để xem mức độ phù hợp');
    }

    if (_isEnglish) return _buildEnglishLevelSelector();

    final options = _levelOptions;
    if (options.length <= 3) {
      return ProfileFormTheme.levelPills(
        options: options,
        selected: _cefrLevel,
        onSelect: (v) => setState(() => _cefrLevel = v),
      );
    }

    return _buildLevelWrap(options, selected: _cefrLevel, onSelect: (v) {
      setState(() => _cefrLevel = v);
    });
  }

  Widget _buildEnglishLevelSelector() {
    final hasCert = _selectedCert != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Khung CEFR',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        _buildLevelWrap(
          LanguageProficiencyLevels.englishCefrLevels,
          selected: hasCert ? null : _cefrLevel,
          onSelect: _selectCefr,
        ),
        const SizedBox(height: 20),
        const Text(
          'Hoặc chọn chứng chỉ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 10),
        ProfileFormTheme.levelPills(
          options: const ['IELTS', 'TOEIC'],
          selected: _selectedCert == _certIelts
              ? 'IELTS'
              : _selectedCert == _certToeic
                  ? 'TOEIC'
                  : null,
          onSelect: (v) => _selectCert(
            v == 'IELTS' ? _certIelts : _certToeic,
          ),
        ),
        if (_selectedCert == _certIelts) ...[
          const SizedBox(height: 12),
          _scoreField(
            label: 'Điểm IELTS',
            hint: 'VD: 6.5, 7.0',
            controller: _ieltsController,
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (_selectedCert == _certToeic) ...[
          const SizedBox(height: 12),
          _scoreField(
            label: 'Điểm TOEIC',
            hint: 'VD: 650, 850',
            controller: _toeicController,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  Widget _scoreField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ProfileFormTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ProfileFormTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: ProfileFormTheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLevelWrap(
    List<String> options, {
    required String? selected,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final active = selected == opt;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: active
                    ? ProfileFormTheme.primary
                    : ProfileFormTheme.border,
                width: active ? 1.5 : 1,
              ),
              color: active
                  ? ProfileFormTheme.primary.withValues(alpha: 0.06)
                  : Colors.white,
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active
                    ? ProfileFormTheme.primary
                    : const Color(0xFF555555),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _placeholderBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProfileFormTheme.border),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
    );
  }
}
