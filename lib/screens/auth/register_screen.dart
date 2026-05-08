import 'package:viecnow/controller/register_controller.dart';
import 'package:flutter/material.dart';
import '../../common/widgets/primary_button.dart';
import '../../common/widgets/social_login_button.dart';
import '../../utils/validators.dart';
import '../../routes/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RegisterController registerController = RegisterController();
  bool isPasswordHidden = true;
  bool agreePolicy = false;

  Future<void> _submitRegister() async {
    final bool isValid = formKey.currentState!.validate();
    if (!isValid) {
      return;
    }
    if (!agreePolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn phải đồng ý Privacy & Terms')),
      );
      return;
    }
    String? error = await registerController.register(
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      username: usernameController.text.trim(),
      email: emailController.text.trim(),
      phone: phoneController.text.trim(),
      password: passwordController.text.trim(),
    );
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.verifyEmail,
      arguments: emailController.text.trim(),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF6), Color(0xFFF1E7D8)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đăng ký tài khoản vật liệu',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nhập thông tin để bắt đầu đặt hàng và quản lý đơn.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                TextFormField(
                  controller: firstNameController,
                  decoration: _inputDecoration('Tên', Icons.person),
                  validator: (value) {
                    return Validators.validateRequired(
                      value ?? '',
                      'Tên',
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lastNameController,
                  decoration: _inputDecoration(
                    'Họ',
                    Icons.person_outline,
                  ),
                  validator: (value) {
                    return Validators.validateRequired(
                      value ?? '',
                      'Họ',
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: usernameController,
                  decoration: _inputDecoration(
                    'Tên đăng nhập',
                    Icons.alternate_email,
                  ),
                  validator: (value) {
                    return Validators.validateRequired(
                      value ?? '',
                      'Tên đăng nhập',
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Email', Icons.email),
                  validator: (value) {
                    return Validators.validateEmail(value ?? '');
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Số điện thoại', Icons.phone),
                  validator: (value) {
                    return Validators.validatePhone(value ?? '');
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: isPasswordHidden,
                  decoration: _inputDecoration(
                    'Mật khẩu',
                    Icons.lock,
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordHidden
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          isPasswordHidden = !isPasswordHidden;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    return Validators.validatePassword(value ?? '');
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: agreePolicy,
                      activeColor: primaryColor,
                      onChanged: (value) {
                        setState(() {
                          agreePolicy = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Wrap(
                        children: [
                          Text('Tôi đồng ý với '),
                          Text(
                            'Chính sách bảo mật',
                            style: TextStyle(
                              color: primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          Text(' và '),
                          Text(
                            'Điều khoản sử dụng',
                            style: TextStyle(
                              color: primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  title: 'Tạo tài khoản',
                  onPressed: _submitRegister,
                ),
                const SizedBox(height: 24),
                const Center(child: Text('OR')),
                const SizedBox(height: 16),
                SocialLoginButton(
                  icon: Icons.g_mobiledata,
                  title: 'Đăng ký với Google',
                  onPressed: () {},
                ),
                const SizedBox(height: 12),
                SocialLoginButton(
                  icon: Icons.facebook,
                  title: 'Đăng ký với Facebook',
                  onPressed: () {},
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
