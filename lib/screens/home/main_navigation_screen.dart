import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1; // home is center (index 1)

  final List<Widget> _screens = [
    const _DashboardPlaceholder(),
    HomeScreen(),
    const ProfileScreen(),
  ];

  static const Color _primary = Color(0xFF2E7D32);
  static const Color _primaryDark = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
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
          // Tab 0: Dashboard
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
                      color: _currentIndex == 0 ? _primary : Colors.grey.shade400,
                      fontWeight: _currentIndex == 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tab 1: Home (floating center button)
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
          // Tab 2: Profile
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
                      color: _currentIndex == 2 ? _primary : Colors.grey.shade400,
                      fontWeight: _currentIndex == 2 ? FontWeight.w600 : FontWeight.normal,
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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Danh mục', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
