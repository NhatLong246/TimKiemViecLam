import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/employer_notification_controller.dart';
import '../../controller/login_controller.dart';
import '../../data/services/attendance_auto_notify_service.dart';
import '../../utils/messaging_bootstrap.dart';
import '../../widgets/floating_message_bubble.dart';
import 'employer_home_screen.dart';
import '../menu_employer/employer_menu_screen.dart';
import 'employer_profile_screen.dart';

// ── Màu employer ───────────────────────────────────────────────────────────
const _gradientColors = [Color(0xFF7B1FA2), Color(0xFF1565C0)];

class EmployerMainNavigationScreen extends StatefulWidget {
  const EmployerMainNavigationScreen({super.key});

  @override
  State<EmployerMainNavigationScreen> createState() => _EmployerMainNavigationScreenState();
}

class _EmployerMainNavigationScreenState extends State<EmployerMainNavigationScreen> {
  int _currentIndex = 1; // home là trung tâm (index 1)

  @override
  void initState() {
    super.initState();
    Get.put(EmployerNotificationController(), permanent: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.find<AuthController>().currentUser?.role == 'employer') {
        MessagingBootstrap.startIfLoggedIn();
        Get.find<EmployerNotificationController>().refreshNow();
        AttendanceAutoNotifyService.instance.startEmployerPolling();
      }
    });
  }

  @override
  void dispose() {
    AttendanceAutoNotifyService.instance.stopEmployerPolling();
    super.dispose();
  }

  final List<Widget> _screens = [
    const EmployerMenuScreen(),
    const EmployerHomeScreen(),
    const EmployerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          const FloatingMessageBubble(isEmployer: true),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _currentIndex = 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: _currentIndex == 0 ? 1.0 : 0.35,
                    child: Image.asset(
                      'assets/images/icons/icons8-dashboard-layout-48-1.png',
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
                          ? const Color(0xFF7B1FA2)
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
              offset: const Offset(0, -28),
              child: Container(
                width: 58,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _gradientColors,
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B1FA2).withOpacity(0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Image.asset(
                    'assets/images/icons/icons8-home-96.png',
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
                      'assets/images/icons/icons8-profile-48 (1).png',
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
                          ? const Color(0xFF7B1FA2)
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

// ── Placeholder for unbuilt tabs ───────────────────────────────────────────
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
              ).createShader(bounds),
              child: const Icon(Icons.construction_rounded, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF424242)),
            ),
            const SizedBox(height: 8),
            const Text('Tính năng đang phát triển', style: TextStyle(color: Color(0xFF9E9E9E))),
          ],
        ),
      ),
    );
  }
}
