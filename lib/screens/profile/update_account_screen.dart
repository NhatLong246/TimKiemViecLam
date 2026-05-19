import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viecnow/controller/login_controller.dart';
import 'package:viecnow/routes/app_routes.dart';
import 'settings/settings_account_screen.dart';
import 'settings/settings_content.dart';
import 'settings/settings_notification_screen.dart';
import 'settings/settings_text_screen.dart';

/// Màn **Cài đặt** (tab Cá nhân → biểu tượng bánh răng).
class UpdateAccountScreen extends StatelessWidget {
  const UpdateAccountScreen({super.key});

  static const Color _primary = Color(0xFF2E7D32);
  static const String _hotline = '0868912250';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF666666)),
        ),
        title: const Text(
          'Cài đặt',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            children: [
              _buildSettingsListCard(context),
              const SizedBox(height: 16),
              _buildLogoutButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsListCard(BuildContext context) {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsTile(
            icon: Icons.account_circle_outlined,
            title: 'Tài khoản',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsAccountScreen(),
              ),
            ),
          ),
          const _SettingsDivider(),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Thông báo',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsNotificationScreen(),
              ),
            ),
          ),
          const _SettingsDivider(),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Hướng dẫn sử dụng',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsTextScreen(
                  title: SettingsContent.userGuideTitle,
                  body: SettingsContent.userGuideBody,
                ),
              ),
            ),
          ),
          const _SettingsDivider(),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Điều khoản sử dụng',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsTextScreen(
                  title: SettingsContent.termsTitle,
                  body: SettingsContent.termsBody,
                ),
              ),
            ),
          ),
          const _SettingsDivider(),
          _SettingsTile(
            icon: Icons.security_outlined,
            title: 'Chính sách bảo mật',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsTextScreen(
                  title: SettingsContent.privacyTitle,
                  body: SettingsContent.privacyBody,
                ),
              ),
            ),
          ),
          const _SettingsDivider(),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Chính sách dữ liệu cá nhân',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsTextScreen(
                  title: SettingsContent.personalDataTitle,
                  body: SettingsContent.personalDataBody,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _SettingsDivider(),
          const SizedBox(height: 12),
          const Text(
            'Hotline hỗ trợ',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF777777),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _callHotline(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_in_talk_outlined,
                    size: 20,
                    color: Color(0xFF666666),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'HCM: $_hotline',
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.call_outlined,
                    size: 20,
                    color: _primary.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callHotline(BuildContext context) async {
    final uri = Uri.parse('tel:$_hotline');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở ứng dụng gọi điện')),
      );
    }
  }

  Widget _buildLogoutButton(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _confirmLogout(context, authController),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE53935)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Đăng xuất',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    AuthController authController,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Đăng xuất',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    await authController.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 24, color: const Color(0xFF767676)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF222222),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFFB0B0B0),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E1E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 22, color: Color(0xFFEDEDED));
  }
}
