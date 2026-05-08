import 'package:flutter/material.dart';
import '../../common/widgets/primary_button.dart';
import '../../routes/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends StatelessWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// Image
              Image.asset(
                'assets/images/animations/sammy-line-man-receives-a-mail.png',
                height: 200,
              ),
              const SizedBox(height: 32),
              const Text(
                'Xác minh địa chỉ email của bạn',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hệ thống đã gửi một liên kết xác minh tới:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              PrimaryButton(
                title: 'Tiếp tục',
                onPressed: () async {
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await user.reload();
                    user = FirebaseAuth.instance.currentUser;
                    if (user!.emailVerified) {
                      Navigator.pushNamed(context, AppRoutes.registerSuccess);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Hãy xác minh email trước khi tiếp tục',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await user.sendEmailVerification();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email xác minh đã được gửi lại'),
                      ),
                    );
                  }
                },
                child: const Text('Gửi lại email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
