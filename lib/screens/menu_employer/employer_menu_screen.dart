import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';

class EmployerMenuScreen extends StatefulWidget {
  const EmployerMenuScreen({super.key});

  @override
  State<EmployerMenuScreen> createState() => _EmployerMenuScreenState();
}

class _EmployerMenuScreenState extends State<EmployerMenuScreen>
    with SingleTickerProviderStateMixin {
  bool _messagesExpanded = false;
  late AnimationController _animController;
  late Animation<double> _expandAnim;

  static const _gradientColors = [Color(0xFF7B1FA2), Color(0xFF1565C0)];

  static const _messageTools = [
    _MenuItem(
      icon: Icons.how_to_reg_outlined,
      iconColor: Color(0xFF7B1FA2),
      title: 'Công cụ điểm danh',
      subtitle: 'Theo dõi chuyên cần từng ca làm',
      route: AppRoutes.attendanceTool,
    ),
    _MenuItem(
      icon: Icons.calendar_month_outlined,
      iconColor: Color(0xFF0277BD),
      title: 'Công cụ tạo lịch',
      subtitle: 'Tạo và phân công ca làm việc',
      route: AppRoutes.scheduleTool,
    ),
    _MenuItem(
      icon: Icons.star_border_rounded,
      iconColor: Color(0xFFF57F17),
      title: 'Công cụ đánh giá',
      subtitle: 'Đánh giá nhân viên sau ca làm',
      route: AppRoutes.ratingTool,
    ),
  ];

  static const _group2Items = [
    _MenuItem(
      icon: Icons.bar_chart_rounded,
      iconColor: Color(0xFF2E7D32),
      title: 'Báo cáo',
      subtitle: 'Xem báo cáo tuyển dụng và chi phí',
      route: AppRoutes.employerReport,
    ),
    _MenuItem(
      icon: Icons.group_outlined,
      iconColor: Color(0xFF6A1B9A),
      title: 'Nhóm',
      subtitle: 'Quản lý nhóm ứng viên của bạn',
      route: AppRoutes.employerGroups,
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
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _expandAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleMessages() {
    setState(() => _messagesExpanded = !_messagesExpanded);
    if (_messagesExpanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

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
      child: Column(
        children: [
          InkWell(
            onTap: _toggleMessages,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Row(
                children: [
                  _iconBox(icon: Icons.chat_bubble_outline_rounded, color: const Color(0xFF1565C0), size: 52, iconSize: 26),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Tin nhắn việc làm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF212121))),
                        SizedBox(height: 3),
                        Text('Quản lý nhóm chat và trao đổi công việc', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _messagesExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    child: Icon(Icons.chevron_right_rounded,
                        color: _messagesExpanded ? const Color(0xFF7B1FA2) : Colors.grey.shade400,
                        size: 26),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Column(
              children: [
                Divider(height: 1, indent: 18, endIndent: 18, color: Colors.grey.shade100),
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F3FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE1D5F5)),
                  ),
                  child: Column(
                    children: [
                      for (int j = 0; j < _messageTools.length; j++) ...[
                        _buildSubItem(_messageTools[j]),
                        if (j < _messageTools.length - 1)
                          Divider(height: 1, indent: 62, endIndent: 16, color: Colors.purple.shade50),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildSubItem(_MenuItem sub) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Get.toNamed(sub.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            _iconBox(icon: sub.icon, color: sub.iconColor, size: 44, iconSize: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF212121))),
                  const SizedBox(height: 2),
                  Text(sub.subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF9E9E9E))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.purple.shade200, size: 22),
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
