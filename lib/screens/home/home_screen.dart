import 'package:flutter/material.dart';
import '../notification/notification_screen.dart';
import '../../widgets/weather_widget.dart';
import 'package:get/get.dart';
import '../../controller/login_controller.dart';
import '../../controller/home_controller.dart';
import '../../controller/messaging_controller.dart';
import '../../data/models/app_notification_model.dart';
import '../../data/services/notification_service.dart';
import '../../utils/messaging_bootstrap.dart';
import '../../data/models/job_post_model.dart';
import '../../routes/app_routes.dart';

const Color _primary = Color(0xFF2E7D32);
const Color _primaryDark = Color(0xFF1B5E20);
const Color _primaryLight = Color(0xFFE8F5E9);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final HomeController _homeController = Get.put(HomeController());

  Future<void> _onRefresh() async {
    await _homeController.refreshJobs();
  }

  @override
  void initState() {
    super.initState();
    MessagingBootstrap.startIfLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildQuickTools()),
            SliverToBoxAdapter(child: _buildSectionHeader()),
            Obx(() {
              if (_homeController.isLoading.value) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: _primary),
                    ),
                  ),
                );
              }

              if (_homeController.errorMessage.value.isNotEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'Có lỗi xảy ra: ${_homeController.errorMessage.value}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }

              final jobs = _homeController.latestJobs;
              if (jobs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'Chưa có công việc nào',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _JobCard(job: jobs[index]),
                    childCount: jobs.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF81C784), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/banners/mapandtt.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Quận 1, TP.HCM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      GetBuilder<AuthController>(
                        init: _authController,
                        builder: (controller) {
                          final user = controller.currentUser;
                          final displayName =
                              (user != null && user.firstName.trim().isNotEmpty)
                              ? user.firstName
                              : 'bạn';
                          return Text(
                            'Chào $displayName 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const WeatherWidget(),
                    const SizedBox(height: 6),
                    GetBuilder<AuthController>(
                      init: _authController,
                      builder: (_) => const _NotificationBellButton(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tìm việc làm ngay hôm nay!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.search),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: const [
                          SizedBox(width: 14),
                          Icon(
                            Icons.search,
                            color: Color(0xFFBDBDBD),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tìm kiếm công việc...',
                              style: TextStyle(
                                color: Color(0xFFBDBDBD),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Image.asset(
                      'assets/images/icons/icons8-hamburger-menu-50.png',
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTools() {
    final tools = [
      {
        'asset': 'assets/images/icons/icons8-price-48.png',
        'label': 'Tham khảo',
        'route': AppRoutes.reference,
      },
      {
        'asset': 'assets/images/icons/icons8-chart-50.png',
        'label': 'Thống kê',
        'route': AppRoutes.stats,
      },
      {
        'asset': 'assets/images/icons/icons8-avatar-48.png',
        'label': 'Hồ sơ',
        'route': AppRoutes.cv,
      },
      {
        'asset': 'assets/images/icons/icons8-calendar-48.png',
        'label': 'Lịch làm',
        'route': AppRoutes.schedule,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Công cụ nhanh',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: tools
                .map(
                  (t) => _buildToolItem(
                    assetPath: t['asset'] as String,
                    label: t['label'] as String,
                    routeName: t['route'] as String,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem({
    required String assetPath,
    required String label,
    required String routeName,
  }) {
    return GestureDetector(
      onTap: () {
        if (_authController.currentUser == null) {
          _requireLogin();
        } else {
          Navigator.pushNamed(context, routeName);
        }
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF81C784), Color(0xFF2E7D32)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Image.asset(assetPath, color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF424242),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          const Text(
            'Việc làm mới nhất',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'Xem tất cả',
              style: TextStyle(
                color: _primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }




  void _requireLogin() {
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
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: _primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: _primary, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đăng nhập để tiếp tục',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn cần có tài khoản để sử dụng tính năng này.',
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
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Đăng nhập',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/register');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Tạo tài khoản',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget riêng biệt cho từng thẻ Job - Obx bên trong sẽ hoạt động độc lập
/// và tự cập nhật màu khi appliedJobStatus thay đổi
class _JobCard extends StatelessWidget {
  final JobPostModel job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.toNamed(AppRoutes.jobDetail, arguments: job);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.asset(
                    'assets/images/banners/default_image.png',
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Container(
                    height: 100,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      job.salaryDisplay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: Color(0xFF9E9E9E),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            job.locationDisplay,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9E9E9E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        job.jobType == 'part_time' ? 'Part-time' : 'Full-time',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: Obx(() {
                        final homeCtrl = Get.find<HomeController>();
                        final status = homeCtrl.appliedJobStatus[job.jobId];
                        final isAccepted = status == 'accepted';
                        final isPending = status == 'pending';
                        final isWithdrawn = status == 'withdrawn';

                        Color btnColor = _primary;
                        String text = 'Ứng tuyển';

                        if (isWithdrawn) {
                          btnColor = Colors.grey.shade500;
                          text = 'Không thể ứng tuyển';
                        } else if (isAccepted) {
                          btnColor = Colors.red;
                          text = 'Đã được nhận';
                        } else if (isPending) {
                          btnColor = Colors.amber.shade700;
                          text = 'Đã ứng tuyển';
                        }

                        return ElevatedButton(
                          onPressed: isWithdrawn
                              ? null  // Không cho click nếu đã withdrawn
                              : () {
                                  Get.toNamed(AppRoutes.jobDetail, arguments: job);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: btnColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade500,
                            disabledForegroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



/// Chuông thông báo: lọc tin nhóm đã tắt thông báo + Obx tin nhắn.
class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton();

  @override
  Widget build(BuildContext context) {
    MessagingBootstrap.ensureController().ensureInboxListening();
    final notifService = NotificationService();

    return StreamBuilder<List<AppNotificationItem>>(
      stream: notifService.streamNotifications(),
      builder: (context, notifSnap) {
        final notifications = notifSnap.data ?? [];

        Widget bell(int total) {
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationScreen(),
              ),
            ),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      total > 0
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  if (total > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          maxWidth: 28,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            total > 99 ? '99+' : '$total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        if (!Get.isRegistered<MessagingController>()) {
          final count = notifications.where((n) => !n.isRead).length;
          return bell(count);
        }

        return Obx(() {
          final mc = Get.find<MessagingController>();
          final notifUnread = mc.visibleUnreadNotificationCount(notifications);
          final chatUnread = mc.unreadTotal.value;
          final total =
              notifUnread > chatUnread ? notifUnread : chatUnread;
          return bell(total);
        });
      },
    );
  }
}
