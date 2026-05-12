import 'package:flutter/material.dart';
import '../../common/styles/app_colors.dart';
import '../../routes/app_routes.dart';
import 'job_criteria_screen.dart';
import 'my_profile_screen.dart';
import 'work_experience_screen.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/login_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _allowEmployerFind = false;
  String _currentWorkStatus = 'Chưa đi làm';
  String _jobSearchStatus = 'Sẵn sàng đi làm ngay';

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

  Widget _buildHeader(BuildContext context, AuthController authController) {
    final user = authController.currentUser;
    final fullName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : 'Người dùng';
    final email = user?.email ?? '';
    final phone = user?.phone ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF81C784), Color(0xFF2E7D32)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              const Expanded(
                child: Text(
                  'Cá nhân',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.updateAccount);
                },
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: Color(0xFFE0E0E0),
                            size: 54,
                          )
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2E7D32)),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _showJobStatusSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Trạng thái tìm việc',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (email.isNotEmpty)
                      _buildHeaderInfo(Icons.email_outlined, email),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildHeaderInfo(Icons.phone_outlined, phone),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyProfileScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text(
                'Hồ sơ của tôi',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.check_circle_outline,
          color: Color(0xFF8CE5E0),
          size: 19,
        ),
      ],
    );
  }

  void _showJobStatusSheet(BuildContext context) {
    var tempWorkStatus = _currentWorkStatus;
    var tempSearchStatus = _jobSearchStatus;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Trạng thái tìm việc',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF222222),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text(
                            'Đóng',
                            style: TextStyle(
                              color: Color(0xFF5E35B1),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error, color: Color(0xFFFF7A1A), size: 25),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Chọn trạng thái tìm việc để tăng khả năng nhận phản hồi từ NTD và thông báo việc mới',
                              style: TextStyle(
                                fontSize: 17,
                                height: 1.25,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildRequiredSheetLabel('Trạng thái công việc hiện tại'),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildStatusChip(
                          title: 'Chưa đi làm',
                          selected: tempWorkStatus == 'Chưa đi làm',
                          onTap: () {
                            setSheetState(() => tempWorkStatus = 'Chưa đi làm');
                          },
                        ),
                        _buildStatusChip(
                          title: 'Đang làm việc',
                          selected: tempWorkStatus == 'Đang làm việc',
                          onTap: () {
                            setSheetState(
                              () => tempWorkStatus = 'Đang làm việc',
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _buildRequiredSheetLabel('Trạng thái tìm việc'),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      direction: Axis.vertical,
                      children: [
                        _buildStatusChip(
                          icon: Icons.bolt,
                          title: 'Sẵn sàng đi làm ngay',
                          selected: tempSearchStatus == 'Sẵn sàng đi làm ngay',
                          onTap: () {
                            setSheetState(
                              () => tempSearchStatus = 'Sẵn sàng đi làm ngay',
                            );
                          },
                        ),
                        _buildStatusChip(
                          icon: Icons.search,
                          title: 'Đang xem xét cơ hội mới',
                          selected:
                              tempSearchStatus == 'Đang xem xét cơ hội mới',
                          onTap: () {
                            setSheetState(
                              () =>
                                  tempSearchStatus = 'Đang xem xét cơ hội mới',
                            );
                          },
                        ),
                        _buildStatusChip(
                          icon: Icons.visibility_off_outlined,
                          title: 'Chưa định chuyển việc',
                          selected: tempSearchStatus == 'Chưa định chuyển việc',
                          onTap: () {
                            setSheetState(
                              () => tempSearchStatus = 'Chưa định chuyển việc',
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 88),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _currentWorkStatus = tempWorkStatus;
                            _jobSearchStatus = tempSearchStatus;
                          });
                          Navigator.pop(sheetContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5E35B1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Lưu thông tin',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

  Widget _buildRequiredSheetLabel(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF222222),
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Color(0xFFE64A4A)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    IconData? icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFF5E35B1) : const Color(0xFFE0E0E0),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22, color: const Color(0xFF222222)),
              const SizedBox(width: 10),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF222222),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile(
    BuildContext context,
    AuthController authController,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 92),
            child: Column(
              children: [
                _buildHeader(context, authController),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                  child: Column(
                    children: [
                      _buildOverviewCard(),
                      const SizedBox(height: 22),
                      _buildVisibilityCard(),
                      const SizedBox(height: 22),
                      _buildJobCriteriaCard(),
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

  Widget _buildOverviewCard() {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng quan hồ sơ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF262626),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nâng cao tỉ lệ kết nối với Nhà Tuyển Dụng\nbằng cách hoàn thiện các mục dưới đây.',
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: Color(0xFF4B4B4B),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE9E9E9)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.business_center_outlined,
                color: Color(0xFFA58A23),
                size: 21,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kinh nghiệm làm việc',
                  style: TextStyle(color: Color(0xFFA58A23), fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkExperienceScreen(),
                    ),
                  );
                },
                child: const Text('Thêm ngay', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityCard() {
    return _ProfileCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIconBox(Icons.groups_2_outlined),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Cho phép Nhà Tuyển Dụng\ntìm thấy bạn',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch(
                value: _allowEmployerFind,
                activeThumbColor: const Color(0xFF2E7D32),
                onChanged: (value) {
                  setState(() => _allowEmployerFind = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bật tìm kiếm để tăng khả năng được liên hệ\nbởi NTD.',
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                color: Color(0xFF9A9A9A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBox(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: const Color(0xFF2E7D32), size: 25),
    );
  }

  Widget _buildJobCriteriaCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JobCriteriaScreen()),
        );
      },
      child: _ProfileCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIconBox(Icons.work_outline),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tiêu chí tìm việc',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const JobCriteriaScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF6D6D6D),
                    size: 27,
                  ),
                ),
              ],
            ),
          ],
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
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Image.asset(
                  'assets/images/icons/icons8-profile-48.png',
                  width: 40,
                  height: 40,
                ),
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

class _ProfileCard extends StatelessWidget {
  final Widget child;

  const _ProfileCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E3E3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
