import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/employer_home_controller.dart';
import '../../controller/employer_notification_controller.dart';
import '../../controller/messaging_controller.dart';
import '../../controller/job_post_controller.dart';
import '../../utils/messaging_bootstrap.dart';
import '../../controller/login_controller.dart';
import '../../data/models/job_post_model.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../post/post_history_screen.dart';

// ── Màu employer (tím → xanh) ──────────────────────────────────────────────
const _gradientColors = [Color(0xFF7B1FA2), Color(0xFF1565C0)];
const _gradientBegin = Alignment.centerLeft;
const _gradientEnd = Alignment.centerRight;

class EmployerHomeScreen extends StatelessWidget {
  const EmployerHomeScreen({super.key});

  static const _quickTools = [
    {
      'asset': 'assets/images/icons/icons8-open-book-100 (1).png',
      'label': 'Tham khảo',
      'route': AppRoutes.employerReference,
    },
    {
      'asset': 'assets/images/icons/icons8-column-chart-100.png',
      'label': 'Thống kê',
      'route': AppRoutes.employerStats,
    },
    {
      'asset': 'assets/images/icons/icons8-cv-100.png',
      'label': 'Ứng viên',
      'route': AppRoutes.employerCandidates,
    },
    {
      'asset': 'assets/images/icons/icons8-create-post-64.png',
      'label': 'Bài đăng',
      'route': AppRoutes.postManagement,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final homeCtrl = Get.put(EmployerHomeController());
    if (!Get.isRegistered<EmployerNotificationController>()) {
      Get.put(EmployerNotificationController(), permanent: true);
    }
    MessagingBootstrap.startIfLoggedIn();
    return GetBuilder<AuthController>(
      builder: (authCtrl) {
        final user = authCtrl.currentUser;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: RefreshIndicator(
            color: const Color(0xFF7B1FA2),
            onRefresh: homeCtrl.refreshHome,
            child: Obx(
              () => CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context, user)),
                  SliverToBoxAdapter(child: _buildQuickTools(context)),
                  SliverToBoxAdapter(child: _buildQuickStats(homeCtrl, user)),
                  SliverToBoxAdapter(
                    child: _buildSectionTitle(context, homeCtrl),
                  ),
                  if (homeCtrl.isLoading.value)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(
                              Color(0xFF7B1FA2),
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (homeCtrl.displayedPosts.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState())
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, index) => _buildJobCard(
                            ctx,
                            homeCtrl.displayedPosts[index],
                          ),
                          childCount: homeCtrl.displayedPosts.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: homeCtrl.hasMore
                          ? _buildLoadMoreButton(homeCtrl)
                          : const SizedBox(height: 100),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, UserModel? user) {
    final name = (user?.companyName?.isNotEmpty == true)
        ? user!.companyName!
        : (user?.firstName.isNotEmpty == true ? user!.firstName : 'Bạn');
    final location = (user?.companyAddress?.isNotEmpty == true)
        ? user!.companyAddress!
        : 'Chưa cập nhật vị trí';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'N';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: _gradientBegin,
          end: _gradientEnd,
          colors: _gradientColors,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Decorative background circles ──
          Positioned(
            top: -18,
            right: -24,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: 28,
            right: 68,
            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -36,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // ── Actual content ──
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: avatar + name/location + bell ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar with initial or real image
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.55),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: user?.companyLogoUrl?.isNotEmpty == true
                            ? Image.network(
                                user!.companyLogoUrl!,
                                fit: BoxFit.cover,
                              )
                            : user?.avatarBase64?.isNotEmpty == true
                            ? Image.memory(
                                base64Decode(user!.avatarBase64!),
                                fit: BoxFit.cover,
                              )
                            : user?.avatarUrl?.isNotEmpty == true
                            ? Image.network(user!.avatarUrl!, fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chào, $name 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white60,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Notification bell — realtime
                    Obx(() {
                      final notifCtrl =
                          Get.find<EmployerNotificationController>();
                      notifCtrl.notifications.length;
                      var count = notifCtrl.notifications
                          .where((n) => !n.isRead)
                          .length;
                      if (Get.isRegistered<MessagingController>()) {
                        final chat =
                            Get.find<MessagingController>().unreadTotal.value;
                        if (chat > count) count = chat;
                      }
                      return GestureDetector(
                        onTap: () =>
                            Get.toNamed(AppRoutes.employerNotifications),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                count > 0
                                    ? Icons.notifications_rounded
                                    : Icons.notifications_none_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            if (count > 0)
                              Positioned(
                                top: -3,
                                right: -3,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 17,
                                    minHeight: 17,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5252),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      count > 99 ? '99+' : '$count',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 18),
                // ── Subtitle ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Colors.white70,
                        size: 13,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Hôm nay bạn muốn tuyển ai?',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── Search bar ──
                Row(
                  children: [
                    // Search input (tap → mở EmployerSearchScreen)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Get.toNamed(AppRoutes.employerSearch),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              Icon(
                                Icons.search_rounded,
                                color: Colors.grey.shade400,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Tìm bài đăng, người làm...',
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
                    // Filter button (tap → mở EmployerSearchScreen + mở filter)
                    GestureDetector(
                      onTap: () => Get.toNamed(
                        AppRoutes.employerSearch,
                        arguments: {'openFilter': true},
                      ),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: _gradientBegin,
                            end: _gradientEnd,
                            colors: _gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B1FA2).withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── QUICK TOOLS ────────────────────────────────────────────────────────────
  Widget _buildQuickTools(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 14),
            child: Text(
              'Công cụ nhanh',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212121),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _quickTools.map((t) => _buildToolItem(t)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem(Map<String, dynamic> tool) {
    final route = tool['route'] as String? ?? '';
    return GestureDetector(
      onTap: route.isNotEmpty ? () => Get.toNamed(route) : null,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: _gradientBegin,
                  end: _gradientEnd,
                  colors: _gradientColors,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B1FA2).withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Image.asset(
                  tool['asset'] as String,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: Text(
                tool['label'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF424242),
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── QUICK STATS ────────────────────────────────────────────────────────────
  Widget _buildQuickStats(EmployerHomeController homeCtrl, UserModel? user) {
    final totalSpent = user?.totalSpent ?? 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3E5F5), Color(0xFFE3F2FD)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFCE93D8).withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: _gradientColors,
                  begin: _gradientBegin,
                  end: _gradientEnd,
                ).createShader(bounds),
                child: const Text(
                  'Thống kê nhanh',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: _gradientBegin,
                    end: _gradientEnd,
                    colors: _gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tháng này',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(
                Icons.work_outline_rounded,
                'Đang tuyển',
                '${homeCtrl.activePostsCount} vị trí',
                const Color(0xFF7B1FA2),
              ),
              _buildStatDivider(),
              _buildStatItem(
                Icons.people_outline_rounded,
                'Đã thuê',
                '${homeCtrl.totalHired} người',
                const Color(0xFF1565C0),
              ),
              _buildStatDivider(),
              _buildStatItem(
                Icons.account_balance_wallet_outlined,
                'Ngân sách\nđã chi',
                _formatVnd(totalSpent),
                const Color(0xFF6A1B9A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatVnd(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M₫';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K₫';
    if (amount == 0) return '0₫';
    return '${amount.toInt()}₫';
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF757575)),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 60,
      color: Colors.purple.withOpacity(0.12),
    );
  }

  // ── SECTION TITLE ──────────────────────────────────────────────────────────
  Widget _buildSectionTitle(
    BuildContext context,
    EmployerHomeController homeCtrl,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Bài đăng tuyển dụng của bạn',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF212121),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Get.to(
                () => const PostHistoryScreen(),
                transition: Transition.rightToLeft,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: _gradientBegin,
                  end: _gradientEnd,
                  colors: _gradientColors,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B1FA2).withOpacity(0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Lịch sử',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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

  // ── EMPTY STATE ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 100),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'Chưa có bài đăng nào',
              style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.createPost),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: _gradientBegin,
                    end: _gradientEnd,
                    colors: _gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Tạo bài đăng mới',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── LOAD MORE BUTTON ───────────────────────────────────────────────────────
  Widget _buildLoadMoreButton(EmployerHomeController homeCtrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: homeCtrl.loadMore,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF7B1FA2), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.expand_more_rounded, color: Color(0xFF7B1FA2)),
          label: const Text(
            'Xem thêm bài đăng',
            style: TextStyle(
              color: Color(0xFF7B1FA2),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ── JOB CARD ───────────────────────────────────────────────────────────────
  Widget _buildJobCard(BuildContext context, JobPostModel job) {
    final typeLabel = job.jobType == 'part_time' ? 'Part-time' : 'Full-time';
    final statusColor = _statusColor(job.status);
    final statusLabel = _statusLabel(job.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: _gradientBegin,
                    end: _gradientEnd,
                    colors: _gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212121),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildTag(
                          job.salaryDisplay,
                          const Color(0xFFE8F5E9),
                          const Color(0xFF2E7D32),
                        ),
                        _buildTag(
                          typeLabel,
                          const Color(0xFFF3E5F5),
                          const Color(0xFF7B1FA2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 12),
          // ── Info row ──
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: Color(0xFF9E9E9E),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  job.locationDisplay.isNotEmpty
                      ? job.locationDisplay
                      : 'Chưa cập nhật',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF757575),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.people_outline_rounded,
                size: 14,
                color: Color(0xFF9E9E9E),
              ),
              const SizedBox(width: 4),
              Text(
                '${job.filledSlots}/${job.slots} vị trí',
                style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Action button ──
          SizedBox(
            width: double.infinity,
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: _gradientBegin,
                  end: _gradientEnd,
                  colors: _gradientColors,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  int tabIndex = 0;
                  try {
                    if (Get.isRegistered<JobPostController>()) {
                      final ctrl = Get.find<JobPostController>();
                      if (ctrl.pendingPosts.any((p) => p.jobId == job.jobId)) {
                        tabIndex = 1;
                      } else if (ctrl.expiredPosts.any((p) => p.jobId == job.jobId)) {
                        tabIndex = 2;
                      } else if (ctrl.pendingDisbursementPosts.any((p) => p.jobId == job.jobId)) {
                        tabIndex = 3;
                      } else if (ctrl.completedPosts.any((p) => p.jobId == job.jobId)) {
                        tabIndex = 4;
                      }
                    }
                  } catch (_) {}
                  Get.toNamed(
                    AppRoutes.postManagement,
                    arguments: {
                      'initialTab': tabIndex,
                      'highlightJobId': job.jobId,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'Quản lý',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
      case 'active':
        return const Color(0xFF2E7D32);
      case 'pending':
        return const Color(0xFFF57F17);
      case 'closed':
      case 'rejected':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF757575);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
      case 'active':
        return 'Đang tuyển';
      case 'pending':
        return 'Chờ duyệt';
      case 'closed':
        return 'Đã đóng';
      case 'rejected':
        return 'Từ chối';
      case 'draft':
        return 'Bản nháp';
      default:
        return 'Không xác định';
    }
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
