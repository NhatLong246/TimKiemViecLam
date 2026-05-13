import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/job_post_controller.dart';
import '../../data/models/job_post_model.dart';
import '../../routes/app_routes.dart';

class PostManagementScreen extends StatelessWidget {
  const PostManagementScreen({super.key});

  static const _gradientColors = [Color(0xFF7B1FA2), Color(0xFF1565C0)];
  static const _gradientBegin = Alignment.centerLeft;
  static const _gradientEnd = Alignment.centerRight;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(JobPostController());

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F8),
        body: Column(
          children: [
            _buildHeader(context),
            _buildCreateButton(),
            _buildTabBar(),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFF7B1FA2)),
                    ),
                  );
                }
                if (controller.errorMessage.value.isNotEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 48, color: Color(0xFFE53935)),
                          const SizedBox(height: 12),
                          const Text(
                            'Không tải được dữ liệu',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            controller.errorMessage.value,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFF757575), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return TabBarView(
                  children: [
                    _buildPostList(controller.publishedPosts, 'published', controller),
                    _buildPostList(controller.pendingPosts, 'pending', controller),
                    _buildPostList(controller.draftPosts, 'draft', controller),
                    _buildPostList(controller.expiredPosts, 'expired', controller),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: _gradientBegin,
          end: _gradientEnd,
          colors: _gradientColors,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              const Expanded(
                child: Text(
                  'Quản lý Bài đăng',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search_rounded,
                    color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── NÚT TẠO BÀI ĐĂNG ──────────────────────────────────────────────────────
  Widget _buildCreateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.createPost),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: _gradientBegin,
              end: _gradientEnd,
              colors: _gradientColors,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B1FA2).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Tạo bài đăng mới',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB BAR ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF9E9E9E),
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            begin: _gradientBegin,
            end: _gradientEnd,
            colors: _gradientColors,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        padding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Đã đăng'),
          Tab(text: 'Chờ duyệt'),
          Tab(text: 'Bản nháp'),
          Tab(text: 'Quá hạn'),
        ],
      ),
    );
  }

  // ── DANH SÁCH BÀI ĐĂNG ────────────────────────────────────────────────────
  Widget _buildPostList(
      List<JobPostModel> posts, String tabType, JobPostController controller) {
    if (posts.isEmpty) {
      return _buildEmptyState(tabType);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: posts.length,
      itemBuilder: (context, index) =>
          _buildPostCard(posts[index], tabType, controller),
    );
  }

  Widget _buildEmptyState(String tabType) {
    final messages = {
      'published': 'Chưa có bài đăng nào được duyệt',
      'pending': 'Không có bài đăng chờ duyệt',
      'draft': 'Chưa có bản nháp nào',
      'expired': 'Không có bài đăng quá hạn',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            messages[tabType] ?? 'Không có dữ liệu',
            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── CARD BÀI ĐĂNG ─────────────────────────────────────────────────────────
  Widget _buildPostCard(
      JobPostModel post, String tabType, JobPostController controller) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    final dateStr = DateFormat('dd/MM/yyyy').format(post.startDate);
    final city = post.location['city'] as String? ?? '';
    final district = post.location['district'] as String? ?? '';
    final locationStr = [district, city].where((s) => s.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Nội dung chính ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr${locationStr.isNotEmpty ? ' • $locationStr' : ''}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusBadge(post.status),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${formatter.format(post.salary.toInt())}đ${post.salaryTypeLabel}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7B1FA2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Menu 3 chấm ──
            _buildPopupMenu(post, tabType, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final config = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config['bgColor'] as Color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        config['label'] as String,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: config['textColor'] as Color,
        ),
      ),
    );
  }

  Map<String, dynamic> _statusConfig(String status) {
    switch (status) {
      case 'approved':
      case 'active':
        return {
          'label': 'Đã đăng',
          'bgColor': const Color(0xFFE8F5E9),
          'textColor': const Color(0xFF2E7D32),
        };
      case 'pending':
        return {
          'label': 'Chờ duyệt',
          'bgColor': const Color(0xFFFFF3E0),
          'textColor': const Color(0xFFE65100),
        };
      case 'draft':
        return {
          'label': 'Bản nháp',
          'bgColor': const Color(0xFFEEEEEE),
          'textColor': const Color(0xFF616161),
        };
      case 'closed':
        return {
          'label': 'Quá hạn',
          'bgColor': const Color(0xFFFFEBEE),
          'textColor': const Color(0xFFC62828),
        };
      case 'rejected':
        return {
          'label': 'Bị từ chối',
          'bgColor': const Color(0xFFFFEBEE),
          'textColor': const Color(0xFFC62828),
        };
      default:
        return {
          'label': status,
          'bgColor': const Color(0xFFEEEEEE),
          'textColor': const Color(0xFF616161),
        };
    }
  }

  Widget _buildPopupMenu(
      JobPostModel post, String tabType, JobPostController controller) {
    final items = <PopupMenuEntry<String>>[];

    if (tabType == 'draft') {
      items.add(const PopupMenuItem(value: 'submit', child: Text('Gửi duyệt')));
      items.add(const PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: Colors.red))));
    } else if (tabType == 'published') {
      items.add(const PopupMenuItem(value: 'close', child: Text('Đóng bài đăng')));
    } else if (tabType == 'pending') {
      items.add(const PopupMenuItem(value: 'retract', child: Text('Rút lại')));
    }
    items.add(const PopupMenuItem(value: 'view', child: Text('Xem chi tiết')));

    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF9E9E9E), size: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        switch (value) {
          case 'submit':
            await controller.submitForReview(post.jobId);
            break;
          case 'delete':
            await controller.deletePost(post.jobId);
            break;
          case 'close':
            await controller.closePost(post.jobId);
            break;
          case 'retract':
            await controller.updatePostStatus(post.jobId, 'draft');
            break;
        }
      },
      itemBuilder: (_) => items,
    );
  }
}
