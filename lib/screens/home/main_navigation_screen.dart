import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/login_controller.dart';
import 'package:viecnow/routes/app_routes.dart';
import '../chatbot/chatbot_screen.dart';
import '../messaging/conversation_list_screen.dart';
import '../menu_candidate/candidate_benefits_screen.dart';
import '../menu_candidate/candidate_groups_screen.dart';
import '../menu_candidate/candidate_reviews_screen.dart';
import 'home_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/floating_chat_button.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1;
  int _previousIndex = 1;

  final List<Widget> _screens = [
    const _DashboardPlaceholder(),
    HomeScreen(),
    const ProfileScreen(),
  ];

  static const Color _primary = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [_screens[_currentIndex], const FloatingChatButton()],
      ),
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                if (_currentIndex == 0) {
                  _currentIndex = _previousIndex;
                } else {
                  _previousIndex = _currentIndex;
                  _currentIndex = 0;
                }
              }),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: _currentIndex == 0 ? 1.0 : 0.35,
                    child: Image.asset(
                      'assets/images/icons/icons8-dashboard-layout-48.png',
                      width: 26,
                      height: 26,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Danh mục',
                    style: TextStyle(
                      fontSize: 10,
                      color: _currentIndex == 0
                          ? _primary
                          : Colors.grey.shade400,
                      fontWeight: _currentIndex == 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _currentIndex = 1),
            child: Transform.translate(
              offset: const Offset(0, -26),
              child: Container(
                width: 72,
                height: 72,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF66BB6A), Color(0xFF42A5F5)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(
                    'assets/images/icons/icons8-home-64.png',
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _currentIndex = 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: _currentIndex == 2 ? 1.0 : 0.35,
                    child: Image.asset(
                      'assets/images/icons/icons8-profile-48.png',
                      width: 26,
                      height: 26,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cá nhân',
                    style: TextStyle(
                      fontSize: 10,
                      color: _currentIndex == 2
                          ? _primary
                          : Colors.grey.shade400,
                      fontWeight: _currentIndex == 2
                          ? FontWeight.w600
                          : FontWeight.normal,
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

class _DashboardPlaceholder extends StatelessWidget {
  const _DashboardPlaceholder();

  static const Color _primary = Color(0xFF2E7D32);

  static const _items = [
    _MenuItem(
      Icons.message_outlined,
      'Message',
      Color(0xFF5C6BC0),
      Color(0xFFEDE7F6),
      requiresAuth: true,
    ),
    _MenuItem(
      Icons.volunteer_activism_outlined,
      'Thụ hưởng',
      Color(0xFFEF6C00),
      Color(0xFFFFF3E0),
      requiresAuth: true,
    ),
    _MenuItem(
      Icons.bar_chart_rounded,
      'Báo cáo',
      Color(0xFF00897B),
      Color(0xFFE0F2F1),
      requiresAuth: true,
    ),
    _MenuItem(
      Icons.group_rounded,
      'Nhóm của bạn',
      Color(0xFF1E88E5),
      Color(0xFFE3F2FD),
      requiresAuth: true,
    ),
    _MenuItem(
      Icons.star_rounded,
      'Đánh giá',
      Color(0xFFD81B60),
      Color(0xFFFCE4EC),
      requiresAuth: true,
    ),
    _MenuItem(
      Icons.smart_toy_outlined,
      'Trợ lý AI',
      Color(0xFF00838F),
      Color(0xFFE0F7FA),
      requiresAuth: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Danh mục',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.55,
                children: _items
                    .map((item) => _buildCard(context, item))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _MenuItem item) {
    return GestureDetector(
      onTap: item.tappable ? () => _onTap(context, item) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.bgColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: item.iconColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(item.icon, size: 22, color: item.iconColor),
            ),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: item.iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context, _MenuItem item) {
    final auth = Get.find<AuthController>();
    if (item.requiresAuth && auth.currentUser == null) {
      _requireLogin(context);
      return;
    }

    final Widget screen;
    switch (item.label) {
      case 'Message':
        screen = const ConversationListScreen();
        break;
      case 'Thụ hưởng':
        screen = const CandidateBenefitsScreen();
        break;
      case 'Báo cáo':
        Navigator.pushNamed(context, AppRoutes.stats);
        return;
      case 'Nhóm của bạn':
        screen = const CandidateGroupsScreen();
        break;
      case 'Đánh giá':
        screen = const CandidateReviewsScreen();
        break;
      case 'Trợ lý AI':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatbotScreen()),
        );
        return;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _requireLogin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.lock_outline, color: _primary, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Đăng nhập để tiếp tục',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn cần đăng nhập để dùng tính năng này.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF757575), fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, AppRoutes.login);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Đăng nhập'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final bool requiresAuth;
  final bool tappable;

  const _MenuItem(
    this.icon,
    this.label,
    this.iconColor,
    this.bgColor, {
    this.requiresAuth = false,
    this.tappable = true,
  });
}
