import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/update_account_controller.dart';
import 'package:viecnow/data/models/candidate_profile_models.dart';
import 'profile_form_theme.dart';

class SelfIntroductionScreen extends StatefulWidget {
  const SelfIntroductionScreen({super.key});

  @override
  State<SelfIntroductionScreen> createState() => _SelfIntroductionScreenState();
}

class _SelfIntroductionScreenState extends State<SelfIntroductionScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
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
      _controller.text = selfIntroductionFromUserData(data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_controller.text.trim().isEmpty) {
      ProfileFormTheme.showSnack(
        context,
        'Vui lòng nhập giới thiệu bản thân',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await Get.find<UpdateAccountController>()
          .saveSelfIntroduction(_controller.text);
      if (!mounted) return;
      ProfileFormTheme.showSnack(context, 'Đã lưu giới thiệu bản thân');
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
      appBar: ProfileFormTheme.buildAppBar(context, 'Giới thiệu bản thân'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileFormTheme.requiredLabel('Mô tả'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _controller,
                      minLines: 6,
                      maxLines: 10,
                      onChanged: (_) => setState(() {}),
                      decoration: ProfileFormTheme.fieldDecoration(
                        hintText: 'Giới thiệu ngắn gọn về bản thân',
                        maxLines: 6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ProfileFormTheme.tipBox(
                      title:
                          '✨ Bạn hãy viết 2-3 câu cụ thể, phù hợp với vị trí ứng tuyển để thu hút nhà tuyển dụng:',
                      bullets: const [
                        'Nêu thế mạnh chính (kỹ năng/ lĩnh vực chuyên môn)',
                        'Định hướng nghề nghiệp (vị trí/ ngành nghề mục tiêu)',
                        'Giá trị nổi bật hoặc thành tựu định lượng được',
                      ],
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: ProfileFormTheme.saveBar(
        saving: _saving,
        enabled: _controller.text.trim().isNotEmpty,
        onSave: _save,
      ),
    );
  }
}
