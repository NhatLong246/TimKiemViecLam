import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common/styles/app_colors.dart';
import '../../common/widgets/primary_button.dart';
import '../../controller/login_controller.dart';
import '../../routes/app_routes.dart';
import '../../utils/validators.dart';
import '../../utils/preferences_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<Offset> _headerSlide;
  late Animation<double> _logoFade;
  late Animation<Offset> _formSlide;
  late Animation<double> _formFade;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.25), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOut)));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _animCtrl,
            curve: const Interval(0.15, 0.6, curve: Curves.easeIn)));
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animCtrl,
            curve: const Interval(0.35, 0.9, curve: Curves.easeOut)));
    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _animCtrl,
            curve: const Interval(0.35, 0.85, curve: Curves.easeIn)));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final rememberMe = await PreferencesHelper.getRememberMe();
    final savedEmail = await PreferencesHelper.getSavedEmail();
    if (mounted) {
      setState(() {
        _rememberMe = rememberMe;
        if (savedEmail != null) _emailController.text = savedEmail;
      });
    }
  }

  void _navigateByRole(String role) {
    final route = role == 'employer'
        ? AppRoutes.employerHome
        : AppRoutes.home;
    Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = await _authController.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      await PreferencesHelper.saveRememberMe(
        _rememberMe,
        _emailController.text.trim(),
      );
      if (mounted) {
        _navigateByRole(user.role);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.contains('Email not verified')) {
          msg = 'Vui lòng xác thực email trước khi đăng nhập';
        }
        _showError(msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authController.loginWithGoogle();
      await PreferencesHelper.saveRememberMe(_rememberMe, user.email);
      if (mounted) {
        _navigateByRole(user.role);
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFacebookLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authController.loginWithFacebook();
      await PreferencesHelper.saveRememberMe(_rememberMe, user.email);
      if (mounted) {
        _navigateByRole(user.role);
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final headerH = (screenH * 0.32).clamp(220.0, 280.0);
    final cardTop = headerH - 32;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Green rounded header ────────────────────────────
          SlideTransition(
            position: _headerSlide,
            child: Container(
              height: headerH,
              decoration: const BoxDecoration(
                gradient: AppColors.candidateGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: SafeArea(
                child: FadeTransition(
                  opacity: _logoFade,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.work_outline_rounded,
                              size: 44, color: Colors.white),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'V24h',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kết nối việc làm – Mở ra cơ hội',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Form (overlaps header) ─────────────────────────
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: cardTop),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SlideTransition(
                    position: _formSlide,
                    child: FadeTransition(
                      opacity: _formFade,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.09),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding:
                            const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Đăng nhập',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.dark),
                              ),
                              const SizedBox(height: 4),
                              const Text('Chào mừng trở lại!',
                                  style: TextStyle(
                                      color: AppColors.grey,
                                      fontSize: 14)),
                              const SizedBox(height: 28),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType:
                                    TextInputType.emailAddress,
                                validator: (v) =>
                                    Validators.validateEmail(v ?? ''),
                                decoration: _inputDeco('Email',
                                    'ten@gmail.com',
                                    Icons.email_outlined),
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                validator: (v) =>
                                    Validators.validatePassword(
                                        v ?? ''),
                                decoration: _inputDeco(
                                    'Mật khẩu', '',
                                    Icons.lock_outline_rounded,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: AppColors.candidatePrimary,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscurePassword =
                                              !_obscurePassword),
                                    )),
                              ),
                              const SizedBox(height: 10),

                              // Remember + Forgot
                              Row(children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor:
                                        AppColors.candidatePrimary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(4)),
                                    onChanged: (v) => setState(
                                        () => _rememberMe = v ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Ghi nhớ',
                                    style: TextStyle(
                                        color: AppColors.grey,
                                        fontSize: 13)),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, AppRoutes.forgetPassword),
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize
                                          .shrinkWrap),
                                  child: const Text('Quên mật khẩu?',
                                      style: TextStyle(
                                          color:
                                              AppColors.candidatePrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                              ]),
                              const SizedBox(height: 24),

                              // Login button
                              PrimaryButton(
                                title: 'Đăng nhập',
                                onPressed: _handleLogin,
                                backgroundColor:
                                    AppColors.candidatePrimary,
                                isLoading: _isLoading,
                              ),
                              const SizedBox(height: 24),

                              // Divider
                              Row(children: [
                                Expanded(
                                    child: Divider(
                                        color: Colors.grey.shade300)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Text('Hoặc đăng nhập với',
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12)),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: Colors.grey.shade300)),
                              ]),
                              const SizedBox(height: 20),

                              _SocialButton(
                                label: 'Tiếp tục với Google',
                                icon: 'G',
                                iconColor: const Color(0xFFDB4437),
                                onTap: _isLoading
                                    ? null
                                    : _handleGoogleLogin,
                              ),
                              const SizedBox(height: 12),
                              _SocialButton(
                                label: 'Tiếp tục với Facebook',
                                icon: 'f',
                                iconColor: const Color(0xFF1877F2),
                                onTap: _isLoading
                                    ? null
                                    : _handleFacebookLogin,
                              ),
                              const SizedBox(height: 28),

                              // Register link
                              Center(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Text('Chưa có tài khoản? ',
                                        style: TextStyle(
                                            color: AppColors.grey)),
                                    GestureDetector(
                                      onTap: () => Navigator.pushNamed(
                                          context, AppRoutes.register),
                                      child: const Text('Đăng ký ngay',
                                          style: TextStyle(
                                            color:
                                                AppColors.candidatePrimary,
                                            fontWeight: FontWeight.bold,
                                          )),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, String hint, IconData icon,
      {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint.isEmpty ? null : hint,
      prefixIcon: Icon(icon, size: 20, color: AppColors.grey),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFB),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide:
            BorderSide(color: AppColors.candidatePrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      labelStyle: const TextStyle(fontSize: 14, color: AppColors.grey),
    );
  }
}

// ─── Wave Clipper ────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 50);
    path.quadraticBezierTo(
        size.width * 0.25, size.height, size.width * 0.5, size.height - 25);
    path.quadraticBezierTo(size.width * 0.75, size.height - 50,
        size.width, size.height - 15);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => false;
}

// ─── Social Button ───────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final String label;
  final String icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(icon,
                      style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.dark)),
            ],
          ),
        ),
      ),
    );
  }
}
