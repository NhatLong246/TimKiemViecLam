import 'package:viecnow/screens/shipping_address/my_shipping_address_screen.dart';
import 'package:flutter/material.dart';
import '../../common/styles/app_colors.dart';
import '../../common/styles/app_text_styles.dart';
import '../../common/widgets/profile_menu_item.dart';
import '../../routes/app_routes.dart';
import '../bank_account/my_bank_account_screen.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/login_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AuthController>(
      builder: (authController) {
        bool loggedIn = authController.currentUser != null;
        if (!loggedIn) {
          return _buildGuestProfile(context);
        }
        return _buildUserProfile(context, authController);
      },
    );
  }

  /// ===== Header xanh =====
  Widget _buildHeader(BuildContext context, AuthController authController) {
    final user = authController.currentUser;
    String fullName = '';
    String email = '';
    if (user != null) {
      fullName = '${user.firstName} ${user.lastName}';
      email = user.email;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      color: AppColors.primaryBlue,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(fontSize: 14, color:
                  Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.updateAccount);
            },
            icon: const Icon(Icons.edit, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context,
      AuthController authController,) {
    final AuthController authController = Get.find<AuthController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context, authController),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountSetting(context),
                    const SizedBox(height: 24),
                    _buildAppSettingLabel(),
                    _buildLogoutButton(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ===== Account Setting =====
  Widget _buildAccountSetting(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cài đặt tài khoản', style: AppTextStyle.title),
        const SizedBox(height: 16),
        ProfileMenuItem(
          icon: Icons.location_on,
          title: 'Địa chỉ của tôi',
          subtitle: 'Quản lý địa chỉ giao hàng',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MyShippingAddressScreen()),
            );
          },
        ),
        ProfileMenuItem(
          icon: Icons.shopping_cart,
          title: 'Giỏ hàng của tôi',
          subtitle: 'Xem các mặt hàng trong giỏ hàng',
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.cartOverview);
          },
        ),
        ProfileMenuItem(
          icon: Icons.account_balance,
          title: 'Tài khoản ngân hàng',
          subtitle: 'Quản lý phương thức thanh toán',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MyBankAccountScreen()),
            );
          },
        ),
        ProfileMenuItem(
          icon: Icons.discount,
          title: 'Mã giảm giá',
          subtitle: 'Xem các mã giảm giá có sẵn',
          onTap: () {},
        ),
        ProfileMenuItem(
          icon: Icons.lock,
          title: 'Bảo mật tài khoản',
          subtitle: 'Cài đặt bảo mật và quyền riêng tư',
          onTap: () {},
        ),
      ],
    );
  }

  /// ===== App Setting label =====
  Widget _buildAppSettingLabel() {
    return Text('Cài đặt ứng dụng', style: AppTextStyle.title);
  }

  Widget _buildLogoutButton(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GestureDetector(
        onTap: () async {
          bool? confirm = await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Đang xuất'),
                content: const Text('Bann có chắc muốn đăng xuất không?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(false);
                    },
                    child: const Text('Hủy'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(true);
                    },
                    child: const Text(
                      'Đăng xuất',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          );
          if (confirm == true) {
            await authController.logout();
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home,
                  (route) => false,
            );
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              'Đăng xuất',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildGuestProfile(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.background,
    body: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
          color: AppColors.primaryBlue,
          child: Column(
            children: [
              const CircleAvatar(
                radius: 40,
                child: Icon(Icons.person, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Guest User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.login);
                },
                child: const Text('Đăng nhập ngay'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
