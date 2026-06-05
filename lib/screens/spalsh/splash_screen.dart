import 'dart:async';
import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';

import 'package:get/get.dart';
import '../../controller/login_controller.dart';
import '../../utils/preferences_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    final auth = Get.find<AuthController>();
    // Wait for the session to be restored from cache/Firebase
    await auth.prepareSessionOnStartup();
    
    // Minimal splash screen delay for visual effect
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    final user = auth.currentUser;
    if (user != null) {
      if (user.role == 'employer') {
        Navigator.pushReplacementNamed(context, AppRoutes.employerHome);
      } else if (user.role == 'admin') {
        Navigator.pushReplacementNamed(context, AppRoutes.adminHome);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } else {
      final onboardingCompleted = await PreferencesHelper.getOnboardingCompleted();
      if (onboardingCompleted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B5E20), // xanh đậm
              Color(0xFF388E3C), // xanh trung
              Color(0xFF66BB6A), // xanh nhạt
            ],
          ),
        ),
        child: Stack(
          children: [
            // Vòng trang trí góc trên trái
            Positioned(
              top: -60,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            // Vòng trang trí góc dưới phải
            Positioned(
              bottom: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            // Nội dung chính
            Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 50,
                      spreadRadius: 8,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(36),
                child: Image.asset(
                  'assets/images/logos/user.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
