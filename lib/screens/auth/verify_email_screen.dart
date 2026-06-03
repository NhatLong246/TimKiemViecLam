import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Màu theo role ──────────────────────────────────────────────────────────
const _candidateGradient = [Color(0xFF1B5E20), Color(0xFF4CAF50)];
const _employerGradient = [Color(0xFF7B1FA2), Color(0xFF1565C0)];

class VerifyEmailScreen extends StatelessWidget {
  final String email;
  final String role; // 'candidate' | 'employer'

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.role = 'candidate',
  });

  bool get _isEmployer => role == 'employer';

  List<Color> get _colors =>
      _isEmployer ? _employerGradient : _candidateGradient;

  Color get _primaryColor =>
      _isEmployer ? const Color(0xFF7B1FA2) : const Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Gradient header ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: _isEmployer ? Alignment.centerLeft : Alignment.topCenter,
                end: _isEmployer
                    ? Alignment.centerRight
                    : Alignment.bottomCenter,
                colors: _colors,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // ── GIF illustration ──
                    Image.asset(
                      'assets/images/email/SmartphonesApplications.gif',
                      height: 200,
                    ),
                    const SizedBox(height: 16),
                    // ── Title ──
                    const Text(
                      'Xác minh địa chỉ email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isEmployer
                          ? 'Hoàn tất tài khoản Doanh nghiệp của bạn'
                          : 'Hoàn tất đăng ký tài khoản của bạn',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
              child: Column(
                children: [
                  // ── Email info card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: _isEmployer
                          ? const Color(0xFFF3E5F5)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _primaryColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.mark_email_unread_outlined,
                          size: 36,
                          color: _primaryColor,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Hệ thống đã gửi một liên kết xác minh tới:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          email,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Vui lòng kiểm tra hộp thư đến\n(kể cả thư mục Spam)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Continue button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: _isEmployer
                              ? Alignment.centerLeft
                              : Alignment.topLeft,
                          end: _isEmployer
                              ? Alignment.centerRight
                              : Alignment.bottomRight,
                          colors: _colors,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          User? user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await user.reload();
                            user = FirebaseAuth.instance.currentUser;
                            if (user!.emailVerified) {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                      'isVerified': true,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                              } catch (_) {}
                              if (!context.mounted) return;
                              Navigator.pushNamed(
                                context,
                                AppRoutes.registerSuccess,
                              );
                            } else {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Hãy xác minh email trước khi tiếp tục',
                                  ),
                                  backgroundColor: _primaryColor,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Tiếp tục',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Resend button ──
                  TextButton.icon(
                    onPressed: () async {
                      User? user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await user.sendEmailVerification();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Email xác minh đã được gửi lại',
                            ),
                            backgroundColor: _primaryColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: _primaryColor,
                    ),
                    label: Text(
                      'Gửi lại email',
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
