import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../common/widgets/primary_button.dart';
import '../../routes/app_routes.dart';
import '../../utils/validators.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    final bool isValid = formKey.currentState!.validate();
    if (!isValid) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );
      if (mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.resetEmailSent,
          arguments: emailController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
      if (e.code == 'user-not-found') {
        errorMessage = 'Không tìm thấy tài khoản với email này.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Email không hợp lệ.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã có lỗi xảy ra. Vui lòng thử lại sau.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khôi phục mật khẩu')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  return Validators.validateEmail(value ?? '');
                },
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                title: 'Gửi yêu cầu',
                isLoading: _isLoading,
                onPressed: _isLoading ? () {} : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
