import 'package:flutter/material.dart';
import '../../common/widgets/primary_button.dart';
import '../../routes/app_routes.dart';

class ResetEmailSentScreen extends StatelessWidget {
  final String email;

  const ResetEmailSentScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, size: 100),
              const SizedBox(height: 24),
              const Text(
                'Yêu cầu đã được gửi',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Liên kết khôi phục mật khẩu đã gửi tới:'),
              const SizedBox(height: 8),
              Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              PrimaryButton(
                title: 'Xong',
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (route) => false,
                  );
                },
              ),
              TextButton(onPressed: () {}, child: const Text('Gửi lại email')),
            ],
          ),
        ),
      ),
    );
  }
}
