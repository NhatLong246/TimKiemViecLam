import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/update_account_controller.dart';
import 'package:viecnow/utils/validators.dart';
import 'profile_form_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  bool get _canChangePassword {
    final user = FirebaseAuth.instance.currentUser;
    return user?.providerData.any((p) => p.providerId == 'password') ?? false;
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await Get.put(UpdateAccountController()).changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      ProfileFormTheme.showSnack(context, 'Đã đổi mật khẩu thành công');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ProfileFormTheme.showSnack(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ProfileFormTheme.buildAppBar(context, 'Đổi mật khẩu'),
      body: !_canChangePassword
          ? _buildSocialOnlyMessage()
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _passwordField(
                      controller: _currentController,
                      label: 'Mật khẩu hiện tại',
                      hint: 'Nhập mật khẩu hiện tại',
                      obscure: _obscureCurrent,
                      onToggle: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                      validator: (v) =>
                          Validators.validatePassword(v ?? ''),
                    ),
                    const SizedBox(height: 20),
                    _passwordField(
                      controller: _newController,
                      label: 'Mật khẩu mới',
                      hint: 'Nhập mật khẩu mới',
                      obscure: _obscureNew,
                      onToggle: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      validator: (v) =>
                          Validators.validatePassword(v ?? ''),
                    ),
                    const SizedBox(height: 20),
                    _passwordField(
                      controller: _confirmController,
                      label: 'Xác nhận mật khẩu mới',
                      hint: 'Nhập lại mật khẩu mới',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Vui lòng xác nhận mật khẩu';
                        }
                        if (v != _newController.text) {
                          return 'Mật khẩu xác nhận không khớp';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _canChangePassword
          ? ProfileFormTheme.saveBar(
              saving: _saving,
              enabled: !_saving,
              onSave: _save,
              label: 'Lưu mật khẩu',
            )
          : null,
    );
  }

  Widget _buildSocialOnlyMessage() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Bạn đăng nhập bằng Google hoặc Facebook. '
        'Tài khoản này không dùng mật khẩu ViecNow.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF555555)),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileFormTheme.requiredLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          decoration: ProfileFormTheme.fieldDecoration(hintText: hint).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF888888),
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}
