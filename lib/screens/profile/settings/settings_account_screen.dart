import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/login_controller.dart';
import 'package:viecnow/controller/update_account_controller.dart';
import 'package:viecnow/routes/app_routes.dart';

/// Màn **Tài khoản** — thông tin đăng nhập, mật khẩu, đăng xuất.
class SettingsAccountScreen extends StatefulWidget {
  const SettingsAccountScreen({super.key});

  @override
  State<SettingsAccountScreen> createState() => _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends State<SettingsAccountScreen> {
  static const Color _bg = Color(0xFFF3F3F3);
  static const Color _link = Color(0xFF1E88E5);
  static const Color _verified = Color(0xFF37B96B);
  static const Color _delete = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Get.find<UpdateAccountController>().syncEmailAfterVerification();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UpdateAccountController());

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF666666)),
        ),
        title: const Text(
          'Tài khoản',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder(
        stream: controller.getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.hasData && snapshot.data!.exists
              ? snapshot.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};
          final auth = Get.find<AuthController>();
          final firebaseUser = FirebaseAuth.instance.currentUser;

          final fullName = [
            data['firstName'],
            data['lastName'],
          ]
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .join(' ');
          final displayName = fullName.isNotEmpty
              ? fullName
              : (auth.currentUser?.firstName ?? '').trim().isNotEmpty
                  ? '${auth.currentUser!.firstName} ${auth.currentUser!.lastName}'
                      .trim()
                  : 'Chưa cập nhật';

          final phone = (data['phone'] ?? auth.currentUser?.phone ?? '')
              .toString()
              .trim();
          final email = (data['email'] ??
                  auth.currentUser?.email ??
                  firebaseUser?.email ??
                  '')
              .toString()
              .trim();

          final emailVerified = firebaseUser?.emailVerified ?? false;
          final phoneVerified = phone.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              children: [
                _AccountCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                        child: Text(
                          'Thông tin tài khoản',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFEDEDED)),
                      const SizedBox(height: 4),
                      _updatableRow(
                        icon: Icons.person_outline,
                        value: displayName,
                        verified: displayName != 'Chưa cập nhật',
                        onUpdate: () => Navigator.pushNamed(
                          context,
                          AppRoutes.changeName,
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFEDEDED)),
                      _updatableRow(
                        icon: Icons.phone_outlined,
                        value: phone.isEmpty ? 'Chưa cập nhật' : phone,
                        verified: phone.isNotEmpty && phoneVerified,
                        onUpdate: () => Navigator.pushNamed(
                          context,
                          AppRoutes.changePhoneNumber,
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFEDEDED)),
                      _updatableRow(
                        icon: Icons.email_outlined,
                        value: email.isEmpty ? 'Chưa cập nhật' : email,
                        verified: email.isNotEmpty && emailVerified,
                        onUpdate: () => Navigator.pushNamed(
                          context,
                          AppRoutes.changeEmail,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _AccountCard(
                  child: _updatableRow(
                    icon: Icons.vpn_key_outlined,
                    value: 'Đổi mật khẩu',
                    showValueAsTitle: true,
                    verified: false,
                    onUpdate: () => Navigator.pushNamed(
                      context,
                      AppRoutes.changePassword,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                TextButton(
                  onPressed: () => _confirmDeleteAccount(context),
                  child: const Text(
                    'Xóa tài khoản',
                    style: TextStyle(
                      color: _delete,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF767676)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: value == 'Chưa cập nhật'
                    ? const Color(0xFFAAAAAA)
                    : const Color(0xFF222222),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _updatableRow({
    required IconData icon,
    required String value,
    required bool verified,
    required VoidCallback onUpdate,
    bool showValueAsTitle = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: const Color(0xFF767676)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: showValueAsTitle ? 16 : 15,
                      fontWeight:
                          showValueAsTitle ? FontWeight.w600 : FontWeight.w500,
                      color: value == 'Chưa cập nhật'
                          ? const Color(0xFFAAAAAA)
                          : const Color(0xFF222222),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (verified) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: _verified,
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onUpdate,
            style: TextButton.styleFrom(
              foregroundColor: _link,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Cập nhật',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản'),
        content: const Text(
          'Hành động này không thể hoàn tác. Toàn bộ dữ liệu hồ sơ và lịch sử ứng tuyển sẽ bị xóa. Bạn có chắc chắn?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: _delete),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      }
      try {
        await user?.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login' && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Vui lòng đăng nhập lại rồi thử xóa tài khoản, hoặc liên hệ hotline hỗ trợ.',
              ),
            ),
          );
        }
      }
      await Get.find<AuthController>().logout();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa tài khoản. Vui lòng thử lại.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

class _AccountCard extends StatelessWidget {
  final Widget child;

  const _AccountCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
