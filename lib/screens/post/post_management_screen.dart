import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/constants/full_time_policy.dart';
import '../../controller/job_post_controller.dart';
import '../../data/models/job_post_model.dart';
import '../../routes/app_routes.dart';
import '../../utils/theme_colors.dart';
import 'post_management_actions.dart';

class PostManagementScreen extends StatefulWidget {
  const PostManagementScreen({super.key});

  @override
  State<PostManagementScreen> createState() => _PostManagementScreenState();
}

class _PostManagementScreenState extends State<PostManagementScreen>
    with SingleTickerProviderStateMixin {
  static const _gradientColors = [Color(0xFF7B1FA2), Color(0xFF1565C0)];
  static const _gradientBegin = Alignment.centerLeft;
  static const _gradientEnd = Alignment.centerRight;

  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  bool _sortByEndingSoon = true;
  late final JobPostController _controller;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<JobPostController>()
        ? Get.find<JobPostController>()
        : Get.put(JobPostController());
    
    int initialIndex = 0;
    if (Get.arguments is Map) {
      initialIndex = Get.arguments['initialTab'] ?? 0;
    }
    
    _tabController = TabController(length: 6, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(_syncSortWithActiveTab);
  }

  @override
  void dispose() {
    _tabController.removeListener(_syncSortWithActiveTab);
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _hasCheckedDeadlines = false;

  void _checkDeadlineNotices() async {
    if (_hasCheckedDeadlines || _controller.isLoading.value) return;
    final postsToNotify = _controller.publishedPosts.where((p) {
      if (p.applicationDeadline == null) return false;
      if (p.underfilledAccepted) return false;
      if (!p.startDate.isAfter(DateTime.now())) return false;
      return DateTime.now().isAfter(p.applicationDeadline!) &&
             p.filledSlots < p.slots;
    }).toList();

    if (postsToNotify.isNotEmpty) {
      _hasCheckedDeadlines = true;
      for (final post in postsToNotify) {
        if (!mounted) break;
        final missing = post.slots - post.filledSlots;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Hết hạn ứng tuyển!'),
            content: Text(
              'Công việc "${post.title}" đã đến hạn ứng tuyển nhưng chưa đủ người.\n'
              'Số lượng hiện tại: ${post.filledSlots}/${post.slots} (Thiếu $missing người).\n\n'
              'Bạn có muốn cho job tiếp tục dù chưa đủ người không? Nếu không, công việc sẽ bị hủy và bạn sẽ được hoàn tiền.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final updated = post.copyWith(underfilledAccepted: true);
                  final ok = await _controller.updatePost(updated);
                  if (ok) {
                    Get.snackbar(
                      'Đã lưu quyết định',
                      'Job được phép tiếp tục dù chưa đủ người.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                },
                child: const Text('Tiếp tục job'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(ctx);
                  _controller.cancelPost(post);
                },
                child: const Text('Hủy Job & Hoàn tiền'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _syncSortWithActiveTab() {
    final shouldSortByEndingSoon = _tabController.index == 0;
    if (_sortByEndingSoon == shouldSortByEndingSoon) return;
    if (!mounted) return;
    setState(() => _sortByEndingSoon = shouldSortByEndingSoon);
  }

  List<JobPostModel> _filter(List<JobPostModel> posts) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return posts;
    return posts.where((p) {
      final city = (p.location['city'] as String? ?? '').toLowerCase();
      final district = (p.location['district'] as String? ?? '').toLowerCase();
      return p.title.toLowerCase().contains(q) ||
          city.contains(q) ||
          district.contains(q);
    }).toList();
  }

  List<JobPostModel> _sorted(List<JobPostModel> posts) {
    final sorted = List<JobPostModel>.from(posts);
    if (_sortByEndingSoon) {
      sorted.sort((a, b) {
        final aEnd = a.endDate ?? DateTime(2999);
        final bEnd = b.endDate ?? DateTime(2999);
        final byEnd = aEnd.compareTo(bEnd);
        if (byEnd != 0) return byEnd;
        return b.startDate.compareTo(a.startDate);
      });
      return sorted;
    }
    sorted.sort((a, b) {
      final aCreated = a.createdAt ?? a.startDate;
      final bCreated = b.createdAt ?? b.startDate;
      return bCreated.compareTo(aCreated);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context),
          if (_showSearch) _buildSearchBar(),
          _buildKpiStrip(),
          _buildCreateButton(),
          _buildSortBar(),
          _buildTabBar(),
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF7B1FA2)),
                  ),
                );
              }
              if (_controller.errorMessage.value.isNotEmpty) {
                return _buildError(_controller.errorMessage.value);
              }
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkDeadlineNotices();
              });

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildPostList(
                      _sorted(_filter(_controller.publishedPosts)),
                      'published',
                      _controller),
                  _buildPostList(
                      _sorted(_filter(_controller.pendingPosts)),
                      'pending',
                      _controller),
                  _buildPostList(
                      _sorted(_filter(_controller.draftPosts)),
                      'draft',
                      _controller),
                  _buildPostList(
                      _sorted(_filter(_controller.expiredPosts)),
                      'expired',
                      _controller),
                  _buildPostList(
                      _sorted(_filter(_controller.pendingDisbursementPosts)),
                      'pendingDisbursement',
                      _controller),
                  _buildPostList(
                      _sorted(_filter(_controller.completedPosts)),
                      'completed',
                      _controller),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Tìm theo tiêu đề, địa điểm...',
          prefixIcon: const Icon(Icons.search, size: 22),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
              context.elevatedSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
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
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: _gradientBegin,
          end: _gradientEnd,
          colors: _gradientColors,
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
                onPressed: () => setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) _searchCtrl.clear();
                }),
                icon: Icon(
                  _showSearch ? Icons.close_rounded : Icons.search_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                color: const Color(0xFF7B1FA2).withValues(alpha: 0.3),
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

  Widget _buildKpiStrip() {
    return Obx(() {
      final total = _controller.allPosts.where((p) => p.status != 'cancelled' && p.status != 'deleted').length;
      final recruiting = _controller.publishedPosts.length;
      final now = DateTime.now();
      final soonEnding = _controller.publishedPosts
          .where((p) =>
              p.endDate != null &&
              p.endDate!.isAfter(now) &&
              p.endDate!.difference(now).inDays <= 2)
          .length;
      final recruitingRate = total == 0 ? 0 : ((recruiting / total) * 100).round();

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: _kpiCard(
                icon: Icons.article_outlined,
                label: 'Tổng bài',
                value: '$total',
                tone: const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _kpiCard(
                icon: Icons.campaign_outlined,
                label: 'Đang tuyển',
                value: '$recruitingRate%',
                tone: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _kpiCard(
                icon: Icons.warning_amber_rounded,
                label: 'Sắp hết hạn',
                value: '$soonEnding',
                tone: const Color(0xFFE65100),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _kpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color tone,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: tone),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: dark ? tone.withValues(alpha: 0.9) : tone,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Text(
            'Sắp xếp nhanh',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Mới nhất'),
            selected: !_sortByEndingSoon,
            onSelected: (_) => setState(() => _sortByEndingSoon = false),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('Sắp hết hạn'),
            selected: _sortByEndingSoon,
            onSelected: (_) => setState(() => _sortByEndingSoon = true),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Obx(
      () => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          labelStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              begin: _gradientBegin,
              end: _gradientEnd,
              colors: _gradientColors,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(4),
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: 'Đã đăng (${_controller.publishedPosts.length})'),
            Tab(text: 'Chờ duyệt (${_controller.pendingPosts.length})'),
            Tab(text: 'Bản nháp (${_controller.draftPosts.length})'),
            Tab(text: 'Quá hạn (${_controller.expiredPosts.length})'),
            Tab(text: 'Chờ GN (${_controller.pendingDisbursementPosts.length})'),
            Tab(text: 'Đã HT (${_controller.completedPosts.length})'),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList(
    List<JobPostModel> posts,
    String tabType,
    JobPostController controller,
  ) {
    if (posts.isEmpty) {
      return _buildEmptyState(tabType);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: posts.length,
      itemBuilder: (context, index) =>
          _buildPostCard(context, posts[index], tabType, controller),
    );
  }

  Widget _buildEmptyState(String tabType) {
    final query = _searchCtrl.text.trim();
    final messages = {
      'published': 'Chưa có bài đăng nào được duyệt',
      'pending': 'Không có bài đăng chờ duyệt',
      'draft': 'Chưa có bản nháp nào',
      'expired': 'Không có bài đăng quá hạn',
      'pendingDisbursement': 'Chưa có công việc nào đang chờ giải ngân',
      'completed': 'Chưa có công việc nào hoàn thành',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            query.isNotEmpty
                ? 'Không tìm thấy bài đăng phù hợp'
                : (messages[tabType] ?? 'Không có dữ liệu'),
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          if (query.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Từ khóa: "$query"',
              style: TextStyle(
                color: context.textSecondary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    JobPostModel post,
    String tabType,
    JobPostController controller,
  ) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    final dateStr = DateFormat('dd/MM/yyyy').format(post.startDate);
    final city = post.location['city'] as String? ?? '';
    final district = post.location['district'] as String? ?? '';
    final locationStr = [district, city].where((s) => s.isNotEmpty).join(', ');
    final hasGroup = post.isPartTimeManaged &&
        post.groupChatId != null &&
        post.groupChatId!.isNotEmpty;
    final isEndingSoon = post.endDate != null &&
        post.endDate!.difference(DateTime.now()).inDays <= 2 &&
        post.endDate!.isAfter(DateTime.now()) &&
        (post.status == 'approved' || post.status == 'active');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => PostManagementActions.viewDetail(post),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$dateStr${locationStr.isNotEmpty ? ' • $locationStr' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildStatusBadge(context, post.status),
                              if (post.isFullTimeReferral)
                                _buildInlineWarningChip(
                                  context,
                                  kFullTimeReferralBadge,
                                  color: const Color(0xFF1565C0),
                                ),
                              if (isEndingSoon)
                                _buildInlineWarningChip(context, 'Sắp hết hạn'),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF3A2A45)
                                      : const Color(0xFFF3E5F5),
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
                              if (post.filledSlots > 0)
                                Text(
                                  '${post.filledSlots}/${post.slots} UV',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildPopupMenu(context, post, tabType, controller),
                  ],
                ),
                const SizedBox(height: 10),
                _buildPriorityAction(context, post, tabType, controller),
                if (tabType == 'published') ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _quickChip(
                        Icons.people_outline,
                        'Ứng viên',
                        () => PostManagementActions.openCandidates(post),
                      ),
                      if (hasGroup && post.isPartTimeManaged)
                        _quickChip(
                          Icons.groups_outlined,
                          'Nhóm',
                          () => PostManagementActions.openGroup(post),
                        ),
                      if (hasGroup && post.isPartTimeManaged)
                        _quickChip(
                          Icons.fact_check_outlined,
                          'Điểm danh',
                          () => PostManagementActions.openAttendance(post),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickChip(IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: const Color(0xFF7B1FA2)),
      label: Text(label, style: TextStyle(fontSize: 11, color: context.textPrimary)),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF3A2A45)
          : const Color(0xFFF3E5F5),
      side: BorderSide(color: context.borderColor.withValues(alpha: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: onTap,
    );
  }

  Widget _buildPriorityAction(
    BuildContext context,
    JobPostModel post,
    String tabType,
    JobPostController controller,
  ) {
    IconData icon;
    String label;
    VoidCallback? onTap;
    bool destructive = false;

    if (tabType == 'published') {
      icon = Icons.people_alt_outlined;
      label = 'Ưu tiên: Xem DS ứng tuyển';
      onTap = () => PostManagementActions.openCandidates(post);
    } else if (tabType == 'pending') {
      icon = Icons.edit_note_rounded;
      label = 'Ưu tiên: Chỉnh sửa nhanh';
      onTap = () => PostManagementActions.editPost(post);
    } else if (tabType == 'draft') {
      icon = Icons.send_rounded;
      label = 'Ưu tiên: Gửi duyệt';
      onTap = () => controller.submitForReview(post.jobId);
    } else if (tabType == 'pendingDisbursement') {
      icon = Icons.hourglass_top_rounded;
      label = 'Ưu tiên: Xem yêu cầu';
      onTap = () => PostManagementActions.openAttendance(post);
    } else if (tabType == 'completed') {
      icon = Icons.history_rounded;
      label = 'Ưu tiên: Xem lịch sử';
      onTap = () => PostManagementActions.viewDetail(post);
    } else if (post.status == 'rejected') {
      icon = Icons.refresh_rounded;
      label = 'Ưu tiên: Sửa và gửi lại';
      onTap = () => PostManagementActions.editPost(post);
    } else if (tabType == 'expired') {
      if (post.isPartTimeManaged && post.groupChatId != null && post.groupChatId!.isNotEmpty) {
        icon = Icons.payment_rounded;
        label = 'Ưu tiên: Xem & Giải ngân';
        onTap = () => PostManagementActions.openAttendance(post);
      } else {
        icon = Icons.delete_outline_rounded;
        label = 'Ưu tiên: Xóa bài đăng';
        destructive = true;
        onTap = () async {
          final ok = await PostManagementActions.confirmDelete(context);
          if (ok) {
            await controller.deletePost(post.jobId);
          }
        };
      }
    } else {
      icon = Icons.delete_outline_rounded;
      label = 'Ưu tiên: Xóa bài đăng';
      destructive = true;
      onTap = () async {
        final ok = await PostManagementActions.confirmDelete(context);
        if (ok) {
          await controller.deletePost(post.jobId);
        }
      };
    }

    final color = destructive ? Colors.red : const Color(0xFF7B1FA2);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.1,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineWarningChip(
    BuildContext context,
    String text, {
    Color? color,
  }) {
    final chipColor = color ?? const Color(0xFFE65100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? chipColor.withValues(alpha: 0.2)
            : chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            color == null
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            size: 12,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final config = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config['bgColor'] as Color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (config['textColor'] as Color).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'] as IconData,
            size: 12,
            color: config['textColor'] as Color,
          ),
          const SizedBox(width: 4),
          Text(
            config['label'] as String,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: config['textColor'] as Color,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _statusConfig(String status) {
    switch (status) {
      case 'approved':
      case 'active':
        return {
          'label': 'Đã đăng',
          'icon': Icons.check_circle_outline_rounded,
          'bgColor': const Color(0xFFE8F5E9),
          'textColor': const Color(0xFF2E7D32),
        };
      case 'pending':
        return {
          'label': 'Chờ duyệt',
          'icon': Icons.schedule_rounded,
          'bgColor': const Color(0xFFFFF3E0),
          'textColor': const Color(0xFFE65100),
        };
      case 'draft':
        return {
          'label': 'Bản nháp',
          'icon': Icons.edit_note_rounded,
          'bgColor': const Color(0xFFEEEEEE),
          'textColor': const Color(0xFF616161),
        };
      case 'closed':
        return {
          'label': 'Đã đóng',
          'icon': Icons.lock_outline_rounded,
          'bgColor': const Color(0xFFFFEBEE),
          'textColor': const Color(0xFFC62828),
        };
      case 'rejected':
        return {
          'label': 'Bị từ chối',
          'icon': Icons.cancel_outlined,
          'bgColor': const Color(0xFFFFEBEE),
          'textColor': const Color(0xFFC62828),
        };
      default:
        return {
          'label': status,
          'icon': Icons.info_outline_rounded,
          'bgColor': const Color(0xFFEEEEEE),
          'textColor': const Color(0xFF616161),
        };
    }
  }

  static PopupMenuItem<String> _menuItem(
    String value,
    String label, {
    IconData? icon,
    Color? textColor,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: textColor ?? const Color(0xFF616161)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _menuItems(
    JobPostModel post,
    String tabType,
  ) {
    final hasGroup = post.isPartTimeManaged &&
        post.groupChatId != null &&
        post.groupChatId!.isNotEmpty;
    final items = <PopupMenuEntry<String>>[];

    items.add(_menuItem('view', 'Xem chi tiết', icon: Icons.visibility_outlined));

    if (tabType == 'draft') {
      items.add(_menuItem('edit', 'Chỉnh sửa', icon: Icons.edit_outlined));
      items.add(_menuItem('submit', 'Gửi duyệt', icon: Icons.send_outlined));
      items.add(_menuItem('duplicate', 'Sao chép bản nháp', icon: Icons.content_copy_outlined));
      items.add(_menuItem('delete', 'Xóa',
          icon: Icons.delete_outline, textColor: Colors.red));
    } else if (tabType == 'pending') {
      items.add(_menuItem('edit', 'Chỉnh sửa', icon: Icons.edit_outlined));
      items.add(_menuItem('duplicate', 'Sao chép thành nháp', icon: Icons.content_copy_outlined));
      items.add(_menuItem('retract', 'Rút về nháp', icon: Icons.undo_outlined));
      if (post.startDate.isAfter(DateTime.now())) {
        items.add(_menuItem('cancel', 'Hủy công việc',
            icon: Icons.cancel_presentation_rounded, textColor: Colors.red));
      }
    } else if (tabType == 'published') {
      items.add(_menuItem('candidates', 'Xem DS ứng tuyển',
          icon: Icons.people_outline));
      items.add(_menuItem('extend7', 'Gia hạn thêm 7 ngày',
          icon: Icons.update_rounded));
      items.add(_menuItem('duplicate', 'Sao chép thành nháp',
          icon: Icons.content_copy_outlined));
      if (hasGroup) {
        items.add(_menuItem('group', 'Quản lý nhóm chat',
            icon: Icons.groups_outlined));
        items.add(_menuItem('attendance', 'Điểm danh',
            icon: Icons.fact_check_outlined));
        items.add(_menuItem('summary', 'Tổng kết điểm danh',
            icon: Icons.summarize_outlined));
        items.add(_menuItem('disburse', 'Giải ngân / Kết thúc ca',
            icon: Icons.payments_outlined));
      }
      items.add(_menuItem('complaints', 'Khiếu nại & sự cố',
          icon: Icons.report_outlined));
      items.add(_menuItem('close', 'Đóng bài đăng',
          icon: Icons.block_flipped, textColor: Colors.orange));
      if (post.startDate.isAfter(DateTime.now())) {
        items.add(_menuItem('cancel', 'Hủy công việc',
            icon: Icons.cancel_presentation_rounded, textColor: Colors.red));
      }
    } else if (tabType == 'expired') {
      if (post.status == 'rejected') {
        items.add(_menuItem('edit', 'Chỉnh sửa & gửi lại',
            icon: Icons.edit_outlined));
        items.add(_menuItem('submit', 'Gửi duyệt lại',
            icon: Icons.send_outlined));
      }
      if (post.status == 'closed') {
        items.add(_menuItem('reopen', 'Mở lại tuyển (chờ duyệt)',
            icon: Icons.refresh_rounded));
      }
      items.add(_menuItem('extend30', 'Gia hạn thêm 30 ngày',
          icon: Icons.calendar_month_outlined));
      items.add(_menuItem('duplicate', 'Sao chép thành nháp',
          icon: Icons.content_copy_outlined));
      items.add(_menuItem('complaints', 'Khiếu nại & sự cố',
          icon: Icons.report_outlined));
      if (post.status == 'closed' || post.status == 'rejected') {
        items.add(_menuItem('delete', 'Xóa bài đăng',
            icon: Icons.delete_outline, textColor: Colors.red));
      }
    }

    return items;
  }

  Widget _buildPopupMenu(
    BuildContext context,
    JobPostModel post,
    String tabType,
    JobPostController controller,
  ) {
    final items = _menuItems(post, tabType);
    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant, size: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) =>
          _onMenuSelected(context, value, post, tabType, controller),
      itemBuilder: (_) => items,
    );
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    String value,
    JobPostModel post,
    String tabType,
    JobPostController controller,
  ) async {
    switch (value) {
      case 'view':
        PostManagementActions.viewDetail(post);
        break;
      case 'edit':
        PostManagementActions.editPost(post);
        break;
      case 'candidates':
        PostManagementActions.openCandidates(post);
        break;
      case 'group':
        await PostManagementActions.openGroup(post);
        break;
      case 'attendance':
        await PostManagementActions.openAttendance(post);
        break;
      case 'summary':
        await PostManagementActions.openAttendanceSummary(post);
        break;
      case 'disburse':
        await PostManagementActions.openDisbursement(post);
        break;
      case 'complaints':
        PostManagementActions.openComplaints();
        break;
      case 'submit':
        await controller.submitForReview(post.jobId);
        break;
      case 'duplicate':
        await controller.duplicateAsDraft(post);
        break;
      case 'extend7':
        await controller.extendPostDuration(post, days: 7);
        break;
      case 'extend30':
        await controller.extendPostDuration(post, days: 30);
        break;
      case 'reopen':
        await controller.reopenPost(post);
        break;
      case 'delete':
        final ok = await PostManagementActions.confirmDelete(context);
        if (ok) await controller.deletePost(post.jobId);
        break;
      case 'close':
        final ok = await PostManagementActions.confirmClose(context, post);
        if (ok) await controller.closePost(post.jobId);
        break;
      case 'retract':
        await controller.updatePostStatus(post.jobId, 'draft');
        break;
      case 'cancel':
        await PostManagementActions.confirmCancelJob(context, post);
        break;
    }
  }
}
