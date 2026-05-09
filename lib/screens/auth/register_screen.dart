import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common/styles/app_colors.dart';
import '../../common/widgets/primary_button.dart';
import '../../controller/register_controller.dart';
import '../../controller/login_controller.dart';
import '../../routes/app_routes.dart';
import '../../utils/validators.dart';

// ─── Colour constants ───────────────────────────────────────────
const _candidateColors = [Color(0xFF1B5E20), Color(0xFF4CAF50)];
const _employerColors  = [Color(0xFF7B1FA2), Color(0xFF1565C0)];

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ─── Controllers ─────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _usernameCtrl   = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _companyCtrl    = TextEditingController();
  final _addressCtrl    = TextEditingController();

  final _registerCtrl = RegisterController();
  final AuthController _authCtrl = Get.find<AuthController>();

  // ─── State ───────────────────────────────────────────────────
  bool _isEmployer        = false;   // false = candidate
  bool _obscurePassword   = true;
  bool _agreePolicy       = false;
  bool _isLoading         = false;

  // ─── Animation ───────────────────────────────────────────────
  late AnimationController _animCtrl;
  late Animation<Offset> _headerSlide;
  late Animation<double>  _headerFade;
  late Animation<Offset>  _formSlide;
  late Animation<double>  _formFade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _headerSlide = Tween<Offset>(
            begin: const Offset(0, -0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOut)));
    _headerFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.1, 0.55, curve: Curves.easeIn)));
    _formSlide = Tween<Offset>(
            begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animCtrl,
            curve: const Interval(0.3, 0.85, curve: Curves.easeOut)));
    _formFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.3, 0.8, curve: Curves.easeIn)));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _usernameCtrl, _emailCtrl,
      _phoneCtrl, _passwordCtrl, _companyCtrl, _addressCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Submit ──────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreePolicy) {
      _showError('Bạn phải đồng ý với Chính sách bảo mật và Điều khoản');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final role = _isEmployer ? 'employer' : 'candidate';
      final error = await _registerCtrl.register(
        firstName:      _firstNameCtrl.text.trim(),
        lastName:       _lastNameCtrl.text.trim(),
        username:       _usernameCtrl.text.trim(),
        email:          _emailCtrl.text.trim(),
        phone:          _phoneCtrl.text.trim(),
        password:       _passwordCtrl.text.trim(),
        role:           role,
        companyName:    _isEmployer ? _companyCtrl.text.trim() : null,
        companyAddress: _isEmployer ? _addressCtrl.text.trim() : null,
      );
      if (!mounted) return;
      if (error != null) {
        _showError(error);
      } else {
        Navigator.pushNamed(context, AppRoutes.verifyEmail,
            arguments: _emailCtrl.text.trim());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authCtrl.loginWithGoogle();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.home, (r) => false);
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFacebook() async {
    setState(() => _isLoading = true);
    try {
      await _authCtrl.loginWithFacebook();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.home, (r) => false);
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.redAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final headerH = (screenH * 0.30).clamp(200.0, 260.0);
    final cardTop = headerH - 28;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        // Wave header (animated gradient via TweenAnimationBuilder)
        SlideTransition(
          position: _headerSlide,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: _isEmployer ? 0 : 1, end: _isEmployer ? 1 : 0),
            duration: const Duration(milliseconds: 450),
            builder: (context, t, _) {
              final colors = [
                Color.lerp(
                    _candidateColors[0], _employerColors[0], t)!,
                Color.lerp(
                    _candidateColors[1], _employerColors[1], t)!,
              ];
              final begin = _isEmployer
                  ? Alignment.centerLeft
                  : Alignment.topCenter;
              final end = _isEmployer
                  ? Alignment.centerRight
                  : Alignment.bottomCenter;
              return ClipPath(
                clipper: _WaveClipper(),
                child: Container(
                  height: headerH,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: begin, end: end, colors: colors),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: SafeArea(
                    child: FadeTransition(
                      opacity: _headerFade,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isEmployer
                                  ? Icons.business_center_outlined
                                  : Icons.person_add_alt_1_outlined,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isEmployer
                                ? 'Tài khoản Doanh nghiệp'
                                : 'Tài khoản Người dùng',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isEmployer
                                ? 'Đăng tin tuyển dụng, quản lý ứng viên'
                                : 'Tìm việc phù hợp, ứng tuyển nhanh',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.88)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),

        // Form card
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
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Role switcher ──────────────
                            _RoleSwitcher(
                              isEmployer: _isEmployer,
                              onChanged: (v) => setState(() => _isEmployer = v),
                            ),
                            const SizedBox(height: 24),

                            // ── Common fields ──────────────
                            Row(children: [
                              Expanded(
                                child: _field(
                                  ctrl: _firstNameCtrl,
                                  label: 'Tên',
                                  icon: Icons.person_outline,
                                  validator: (v) => Validators.validateName(v ?? '', 'Tên'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  ctrl: _lastNameCtrl,
                                  label: 'Họ',
                                  icon: Icons.badge_outlined,
                                  validator: (v) => Validators.validateName(v ?? '', 'Họ'),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 14),
                            _field(
                              ctrl: _usernameCtrl,
                              label: 'Tên đăng nhập',
                              icon: Icons.alternate_email,
                              validator: (v) => Validators.validateUsername(v ?? ''),
                            ),
                            const SizedBox(height: 14),
                            _field(
                              ctrl: _emailCtrl,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboard: TextInputType.emailAddress,
                              validator: (v) => Validators.validateEmail(v ?? ''),
                            ),
                            const SizedBox(height: 14),
                            _field(
                              ctrl: _phoneCtrl,
                              label: 'Số điện thoại',
                              icon: Icons.phone_outlined,
                              keyboard: TextInputType.phone,
                              validator: (v) => Validators.validatePhone(v ?? ''),
                            ),
                            const SizedBox(height: 14),

                            // Password
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              validator: (v) => Validators.validatePassword(v ?? ''),
                              decoration: _deco(
                                'Mật khẩu',
                                Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _isEmployer
                                        ? AppColors.employerPrimary
                                        : AppColors.candidatePrimary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),

                            // ── Employer-only fields ───────
                            AnimatedSize(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                              child: _isEmployer
                                  ? Column(children: [
                                      const SizedBox(height: 14),
                                      _field(
                                        ctrl: _companyCtrl,
                                        label: 'Tên công ty',
                                        icon: Icons.business_outlined,
                                        validator: (v) =>
                                            Validators.validateRequired(
                                                v ?? '', 'Tên công ty'),
                                      ),
                                      const SizedBox(height: 14),
                                      _field(
                                        ctrl: _addressCtrl,
                                        label: 'Địa chỉ công ty',
                                        icon: Icons.location_on_outlined,
                                        validator: (v) =>
                                            Validators.validateRequired(
                                                v ?? '', 'Địa chỉ công ty'),
                                      ),
                                    ])
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 16),

                            // ── Policy checkbox ────────────
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: _agreePolicy,
                                    activeColor: _isEmployer
                                        ? AppColors.employerPrimary
                                        : AppColors.candidatePrimary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                    onChanged: (v) =>
                                        setState(() => _agreePolicy = v ?? false),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Wrap(children: [
                                    const Text('Tôi đồng ý với ',
                                        style: TextStyle(fontSize: 12, color: AppColors.grey)),
                                    GestureDetector(
                                      child: const Text('Chính sách bảo mật',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.candidatePrimary,
                                              decoration: TextDecoration.underline)),
                                    ),
                                    const Text(' và ', style: TextStyle(fontSize: 12, color: AppColors.grey)),
                                    GestureDetector(
                                      child: const Text('Điều khoản sử dụng',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.candidatePrimary,
                                              decoration: TextDecoration.underline)),
                                    ),
                                  ]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            // ── Register button ────────────
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: _isEmployer ? 0 : 1, end: _isEmployer ? 1 : 0),
                              duration: const Duration(milliseconds: 450),
                              builder: (ctx, t, _) {
                                final color = Color.lerp(
                                  AppColors.candidatePrimary,
                                  AppColors.employerPrimary,
                                  t,
                                )!;
                                return PrimaryButton(
                                  title: _isEmployer ? 'Tạo tài khoản Doanh nghiệp' : 'Tạo tài khoản',
                                  onPressed: _submit,
                                  backgroundColor: color,
                                  isLoading: _isLoading,
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            // ── Social divider ────────────
                            Row(children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Hoặc đăng ký với',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ]),
                            const SizedBox(height: 16),

                            _SocialBtn(
                              label: 'Tiếp tục với Google',
                              icon: 'G',
                              iconColor: const Color(0xFFDB4437),
                              onTap: _isLoading ? null : _handleGoogle,
                            ),
                            const SizedBox(height: 10),
                            _SocialBtn(
                              label: 'Tiếp tục với Facebook',
                              icon: 'f',
                              iconColor: const Color(0xFF1877F2),
                              onTap: _isLoading ? null : _handleFacebook,
                            ),
                            const SizedBox(height: 24),

                            // ── Login link ────────────────
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Đã có tài khoản? ',
                                      style: TextStyle(color: AppColors.grey)),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Text(
                                      'Đăng nhập',
                                      style: TextStyle(
                                        color: _isEmployer
                                            ? AppColors.employerPrimary
                                            : AppColors.candidatePrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
      ]),
    );
  }

  // ─── Field helpers ──────────────────────────────────────────
  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: validator,
      decoration: _deco(label, icon),
    );
  }

  InputDecoration _deco(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppColors.grey),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isEmployer
                ? AppColors.employerPrimary
                : AppColors.candidatePrimary,
            width: 1.5,
          )),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.grey),
    );
  }
}

// ─── Role switcher ──────────────────────────────────────────────

class _RoleSwitcher extends StatelessWidget {
  final bool isEmployer;
  final ValueChanged<bool> onChanged;

  const _RoleSwitcher({required this.isEmployer, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _Tab(
          label: 'Người dùng',
          icon: Icons.person_outline,
          active: !isEmployer,
          activeColor: AppColors.candidatePrimary,
          onTap: () => onChanged(false),
        ),
        _Tab(
          label: 'Doanh nghiệp',
          icon: Icons.business_center_outlined,
          active: isEmployer,
          activeColor: AppColors.employerPrimary,
          onTap: () => onChanged(true),
        ),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : AppColors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? Colors.white : AppColors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Wave Clipper ────────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 40);
    path.quadraticBezierTo(
        size.width * 0.25, size.height, size.width * 0.5, size.height - 20);
    path.quadraticBezierTo(
        size.width * 0.75, size.height - 40, size.width, size.height - 10);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => false;
}

// ─── Social Button ───────────────────────────────────────────────

class _SocialBtn extends StatelessWidget {
  final String label;
  final String icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _SocialBtn({
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
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: Center(
                  child: Text(icon,
                      style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.dark)),
            ],
          ),
        ),
      ),
    );
  }
}