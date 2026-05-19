import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';

class EmployerMenuScreen extends StatelessWidget {
  const EmployerMenuScreen({super.key});

  static const _gradientColors = [Color(0xFF7B1FA2), Color(0xFF1565C0)];

  static const _group2Items = [
    _MenuItem(
      icon: Icons.bar_chart_rounded,
      iconColor: Color(0xFF2E7D32),
      title: 'Báo cáo',
      subtitle: 'Xem báo cáo tuyển dụng và chi phí',
      route: AppRoutes.employerStats,
    ),
    _MenuItem(
      icon: Icons.account_balance_wallet_outlined,
      iconColor: Color(0xFFAD1457),
      title: 'Tiền app',
      subtitle: 'Nạp, rút tiền và lịch sử giao dịch',
      route: AppRoutes.employerWallet,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildGroup1(),
                const SizedBox(height: 16),
                _buildGroup2(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: _gradientColors,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Các công cụ quản lý tuyển dụng',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroup1() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.toNamed(AppRoutes.employerMessages),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              _iconBox(
                icon: Icons.chat_bubble_outline_rounded,
                color: const Color(0xFF1565C0),
                size: 52,
                iconSize: 26,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF212121),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Nhóm chat & trò chuyện trực tiếp',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroup2() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < _group2Items.length; i++) ...[
            _buildItem(_group2Items[i]),
            if (i < _group2Items.length - 1)
              Divider(height: 1, indent: 86, color: Colors.grey.shade100),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(_MenuItem item) {
    return InkWell(
      onTap: () => Get.toNamed(item.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Row(
          children: [
            _iconBox(icon: item.icon, color: item.iconColor, size: 52, iconSize: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF212121))),
                  const SizedBox(height: 3),
                  Text(item.subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 26),
          ],
        ),
      ),
    );
  }

  Widget _iconBox({required IconData icon, required Color color, required double size, required double iconSize}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String route;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}
