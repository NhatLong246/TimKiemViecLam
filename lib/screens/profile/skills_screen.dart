import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/update_account_controller.dart';
import 'package:viecnow/data/models/candidate_profile_models.dart';
import 'profile_form_theme.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  static const int _maxSkills = 20;

  final _inputController = TextEditingController();
  final List<String> _skills = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap =
          await Get.put(UpdateAccountController()).getUserData().first;
      if (!mounted) return;
      final data = snap.exists
          ? snap.data() as Map<String, dynamic>
          : <String, dynamic>{};
      _skills
        ..clear()
        ..addAll(skillsFromUserData(data));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addSkill() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (_skills.length >= _maxSkills) {
      ProfileFormTheme.showSnack(
        context,
        'Tối đa $_maxSkills kỹ năng',
        error: true,
      );
      return;
    }
    if (_skills.any((s) => s.toLowerCase() == text.toLowerCase())) {
      ProfileFormTheme.showSnack(context, 'Kỹ năng đã tồn tại', error: true);
      return;
    }
    setState(() {
      _skills.add(text);
      _inputController.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Get.find<UpdateAccountController>().saveSkills(_skills);
      if (!mounted) return;
      ProfileFormTheme.showSnack(context, 'Đã lưu kỹ năng');
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
      appBar: ProfileFormTheme.buildAppBar(context, 'Kỹ năng'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileFormTheme.requiredLabel(
                    'Kỹ năng (Tối đa $_maxSkills kỹ năng)',
                    required: false,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _inputController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addSkill(),
                    decoration: ProfileFormTheme.fieldDecoration(
                      hintText: 'Nhập kỹ năng',
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: ProfileFormTheme.primary,
                        ),
                        onPressed: _addSkill,
                      ),
                    ),
                  ),
                  if (_skills.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _skills.map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ProfileFormTheme.primary),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                skill,
                                style: const TextStyle(
                                  color: ProfileFormTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _skills.remove(skill)),
                                child: const Icon(
                                  Icons.cancel,
                                  size: 18,
                                  color: ProfileFormTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
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
