import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/routes/app_routes.dart';

// ── Màu employer (tím → xanh) ──────────────────────────────────────────────
const _gradientColors = [Color(0xFF7B1FA2), Color(0xFF1565C0)];
const _gradientBegin = Alignment.centerLeft;
const _gradientEnd = Alignment.centerRight;

class EmployerHomeScreen extends StatelessWidget {
  const EmployerHomeScreen({super.key});

  // ── Mock data ──────────────────────────────────────────────────────────────
  static const _quickTools = [
    {'asset': 'assets/images/icons/icons8-open-book-100 (1).png', 'label': 'Tham khảo', 'route': AppRoutes.employerReference},
    {'asset': 'assets/images/icons/icons8-column-chart-100.png', 'label': 'Thống kê', 'route': AppRoutes.employerStats},
    {'asset': 'assets/images/icons/icons8-cv-100.png', 'label': 'Ứng viên', 'route': AppRoutes.employerCandidates},
    {'asset': 'assets/images/icons/icons8-create-post-64.png', 'label': 'Bài đăng', 'route': AppRoutes.postManagement},
  ];

  static final _myJobs = [
    {
      'title': 'Nhân viên phục vụ nhà hàng',
      'salary': '250k/ngày',
      'type': 'Part-time',
      'location': 'Quận 1, TP.HCM',
      'applicants': 5,
      'slots': 3,
    },
    {
      'title': 'Nhân viên pha chế',
      'salary': '280k/ngày',
      'type': 'Full-time',
      'location': 'Quận 3, TP.HCM',
      'applicants': 8,
      'slots': 2,
    },
    {
      'title': 'Nhân viên kho hàng',
      'salary': '300k/ngày',
      'type': 'Part-time',
      'location': 'Quận 12, TP.HCM',
      'applicants': 12,
      'slots': 5,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildQuickTools()),
          SliverToBoxAdapter(child: _buildQuickStats()),
          SliverToBoxAdapter(child: _buildSectionTitle('Bài đăng tuyển dụng của bạn')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildJobCard(_myJobs[index]),
                childCount: _myJobs.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: _gradientBegin,
          end: _gradientEnd,
          colors: _gradientColors,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: location + bell ──
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 15),
                const SizedBox(width: 4),
                const Text(
                  'Quận 1, TP.HCM',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5252),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('3', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Greeting ──
            const Text(
              'Chào Nhân đẹp trai 👋',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hôm nay bạn muốn tuyển ai?',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            // ── Search bar ──
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tìm kiếm người làm/ứng viên...',
                      style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: _gradientBegin,
                        end: _gradientEnd,
                        colors: _gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── QUICK TOOLS ────────────────────────────────────────────────────────────
  Widget _buildQuickTools() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 14),
            child: Text(
              'Công cụ nhanh',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF212121)),
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
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF424242)),
              maxLines: 2,
            ),
          ),
        ],
        ),
      ),
    );
  }

  // ── QUICK STATS ────────────────────────────────────────────────────────────
  Widget _buildQuickStats() {
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
        border: Border.all(color: const Color(0xFFCE93D8).withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: _gradientBegin,
                    end: _gradientEnd,
                    colors: _gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Tháng này', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(Icons.work_outline_rounded, 'Đang tuyển', '3 vị trí', const Color(0xFF7B1FA2)),
              _buildStatDivider(),
              _buildStatItem(Icons.people_outline_rounded, 'Đã thuê', '12 người', const Color(0xFF1565C0)),
              _buildStatDivider(),
              _buildStatItem(Icons.account_balance_wallet_outlined, 'Ngân sách\nđã chi', '5.000.000đ', const Color(0xFF6A1B9A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
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
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
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
    return Container(width: 1, height: 60, color: Colors.purple.withOpacity(0.12));
  }

  // ── SECTION TITLE ──────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF212121))),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: _gradientColors,
              begin: _gradientBegin,
              end: _gradientEnd,
            ).createShader(bounds),
            child: const Text('Xem tất cả', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── JOB CARD ───────────────────────────────────────────────────────────────
  Widget _buildJobCard(Map<String, dynamic> job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2)),
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
                child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['title'] as String,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF212121)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildTag(job['salary'] as String, const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                        const SizedBox(width: 6),
                        _buildTag(job['type'] as String, const Color(0xFFF3E5F5), const Color(0xFF7B1FA2)),
                      ],
                    ),
                  ],
                ),
              ),
              // ── Menu button ──
              GestureDetector(
                onTap: () {},
                child: const Icon(Icons.more_vert_rounded, color: Color(0xFF9E9E9E), size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 12),
          // ── Info row ──
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF9E9E9E)),
              const SizedBox(width: 4),
              Text(job['location'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
              const Spacer(),
              const Icon(Icons.people_outline_rounded, size: 14, color: Color(0xFF9E9E9E)),
              const SizedBox(width: 4),
              Text(
                '${job['applicants']} người đã ứng tuyển',
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
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'Quản lý',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
