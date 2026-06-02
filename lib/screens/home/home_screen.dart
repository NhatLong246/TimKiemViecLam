import 'dart:convert';
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildJobCard(jobs[index]),
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
                GetBuilder<AuthController>(
                  init: _authController,
                  builder: (controller) {
                    final user = controller.currentUser;
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.55), width: 2),
                      ),
                      child: ClipOval(
                        child: user?.avatarBase64?.isNotEmpty == true
                            ? Image.memory(base64Decode(user!.avatarBase64!), fit: BoxFit.cover)
                            : user?.avatarUrl?.isNotEmpty == true
                                ? Image.network(user!.avatarUrl!, fit: BoxFit.cover)
                                : Center(
                                    child: Text(
                                      (user != null && user.firstName.trim().isNotEmpty)
                                          ? user.firstName[0].toUpperCase()
                                          : 'N',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                      ),
                    );
                  },
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
                GestureDetector(
                  onTap: () => _showFilterBottomSheet(context),
                  child: Container(
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

  void _showFilterBottomSheet(BuildContext context) {
    final List<String> provinces = [
      'Tất cả', 'Hà Nội', 'TP.HCM', 'Đà Nẵng', 'Hải Phòng', 'Cần Thơ',
      'An Giang', 'Bà Rịa - Vũng Tàu', 'Bắc Giang', 'Bắc Kạn', 'Bạc Liêu', 'Bắc Ninh',
      'Bến Tre', 'Bình Định', 'Bình Dương', 'Bình Phước', 'Bình Thuận', 'Cà Mau',
      'Cao Bằng', 'Đắk Lắk', 'Đắk Nông', 'Điện Biên', 'Đồng Nai', 'Đồng Tháp',
      'Gia Lai', 'Hà Giang', 'Hà Nam', 'Hà Tĩnh', 'Hải Dương', 'Hậu Giang',
      'Hòa Bình', 'Hưng Yên', 'Khánh Hòa', 'Kiên Giang', 'Kon Tum', 'Lai Châu',
      'Lâm Đồng', 'Lạng Sơn', 'Lào Cai', 'Long An', 'Nam Định', 'Nghệ An',
      'Ninh Bình', 'Ninh Thuận', 'Phú Thọ', 'Phú Yên', 'Quảng Bình', 'Quảng Nam',
      'Quảng Ngãi', 'Quảng Ninh', 'Quảng Trị', 'Sóc Trăng', 'Sơn La', 'Tây Ninh',
      'Thái Bình', 'Thái Nguyên', 'Thanh Hóa', 'Thừa Thiên Huế', 'Tiền Giang',
      'Trà Vinh', 'Tuyên Quang', 'Vĩnh Long', 'Vĩnh Phúc', 'Yên Bái'
    ];

    double? tempMinSalary = _homeController.filterMinSalary.value;
    double? tempMaxSalary = _homeController.filterMaxSalary.value;
    String tempLocation = _homeController.filterLocation.value;
    String tempJobType = _homeController.filterJobType.value;

    final minCtrl = TextEditingController(text: tempMinSalary?.toInt().toString() ?? '');
    final maxCtrl = TextEditingController(text: tempMaxSalary?.toInt().toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F5F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            Widget buildChoiceChip(String label, String currentVal, Function(String) onSelect) {
              final isSelected = currentVal == label;
              return ChoiceChip(
                label: Text(
                  isSelected && label == 'Tất cả' ? '✓ Tất cả' : label,
                  style: TextStyle(
                    color: isSelected ? Colors.black87 : Colors.black54,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFFC8E6C9),
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF81C784) : Colors.grey.shade300,
                  ),
                ),
                onSelected: (_) => onSelect(label),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bộ lọc tìm kiếm',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.expand_more, size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    const Text('Khoảng mức lương (VNĐ)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'TỐI THIỂU',
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.green.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.green.shade200),
                              ),
                            ),
                            onChanged: (val) => tempMinSalary = double.tryParse(val),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('-', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'TỐI ĐA',
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.green.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.green.shade200),
                              ),
                            ),
                            onChanged: (val) => tempMaxSalary = double.tryParse(val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text('Khu vực', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: provinces.contains(tempLocation) ? tempLocation : 'Tất cả',
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_drop_down),
                      isExpanded: true,
                      items: provinces.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => tempLocation = val);
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text('Loại công việc', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        buildChoiceChip('Tất cả', tempJobType, (val) => setState(() => tempJobType = val)),
                        buildChoiceChip('Part-time', tempJobType, (val) => setState(() => tempJobType = val)),
                        buildChoiceChip('Full-time', tempJobType, (val) => setState(() => tempJobType = val)),
                      ],
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          _homeController.applyAdvancedFilter(
                            minSalary: tempMinSalary,
                            maxSalary: tempMaxSalary,
                            location: tempLocation,
                            jobType: tempJobType,
                          );
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Áp dụng', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Obx(() {
            final filter = _homeController.filterJobType.value;
            String label = 'Việc làm mới nhất';
            if (filter == 'Part-time') label += ' (Part-time)';
            if (filter == 'Full-time') label += ' (Full-time)';
            return Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            );
          }),
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

  Widget _buildJobCard(JobPostModel job) {
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
            // Banner image with salary overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Builder(builder: (context) {
                    if (job.imageUrls.isEmpty) {
                      return Image.asset(
                        'assets/images/banners/default_image.png',
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      );
                    }
                    final img = job.imageUrls.first;
                    if (img.startsWith('http')) {
                      return Image.network(
                        img,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Image.asset(
                          'assets/images/banners/default_image.png',
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      );
                    } else {
                      try {
                        String b64 = img;
                        if (b64.contains(',')) {
                          b64 = b64.split(',').last;
                        }
                        final sanitized = b64.replaceAll(RegExp(r'\s+'), '');
                        // Thêm padding nếu thiếu
                        final padded = sanitized.padRight(sanitized.length + (4 - sanitized.length % 4) % 4, '=');
                        return Image.memory(
                          base64Decode(padded),
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Image.asset(
                            'assets/images/banners/default_image.png',
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        );
                      } catch (e) {
                        print('Lỗi base64 HomeScreen: $e');
                        return Image.asset(
                          'assets/images/banners/default_image.png',
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        );
                      }
                    }
                  }),
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
            // Content below image
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
                        final hasApplied = _homeController.appliedJobIds.contains(job.jobId);
                        return ElevatedButton(
                          onPressed: hasApplied ? null : () {
                            Get.toNamed(AppRoutes.jobDetail, arguments: job);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasApplied ? Colors.grey.shade400 : _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            hasApplied ? 'Đã ứng tuyển' : 'Ứng tuyển',
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
