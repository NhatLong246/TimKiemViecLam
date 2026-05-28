import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../data/models/job_post_model.dart';
import '../../routes/app_routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmployerSearchScreen
// Argument (optional): Map {'openFilter': true}
// ─────────────────────────────────────────────────────────────────────────────
class EmployerSearchScreen extends StatefulWidget {
  const EmployerSearchScreen({super.key});

  @override
  State<EmployerSearchScreen> createState() => _EmployerSearchScreenState();
}

class _EmployerSearchScreenState extends State<EmployerSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  String _query = '';

  // ── Bộ lọc bài đăng ──────────────────────────────────────────────────────
  String _postStatus = 'all';    // all|pending|approved|active|closed|rejected
  String _postJobType = 'all';   // all|full_time|part_time

  // ── Bộ lọc người làm ─────────────────────────────────────────────────────
  String _workerSort = 'name';   // name|date

  // Firestore
  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();

      final args = Get.arguments;
      if (args is Map && args['openFilter'] == true) {
        Future.delayed(const Duration(milliseconds: 400), _showFilterSheet);
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildSearchHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _PostsTab(
                  query: _query,
                  status: _postStatus,
                  jobType: _postJobType,
                  uid: _uid ?? '',
                  db: _db,
                ),
                _WorkersTab(
                  query: _query,
                  sort: _workerSort,
                  uid: _uid ?? '',
                  db: _db,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header với search bar ─────────────────────────────────────────────────
  Widget _buildSearchHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: Get.back,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              // Search input
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search_rounded,
                          color: Colors.grey.shade400, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _focusNode,
                          onChanged: (v) => setState(() => _query = v.trim()),
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF1A1A2E)),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Tìm bài đăng, người làm...',
                            hintStyle: TextStyle(
                                color: Colors.grey.shade400, fontSize: 14),
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: Colors.grey.shade400),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Filter button
              GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.35), width: 1.2),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Center(
                        child: Icon(Icons.tune_rounded,
                            color: Colors.white, size: 22),
                      ),
                      if (_hasActiveFilter())
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5252),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tab,
        labelColor: const Color(0xFF7B1FA2),
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        indicatorColor: const Color(0xFF7B1FA2),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.work_outline_rounded, size: 18),
                SizedBox(width: 6),
                Text('Bài đăng'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline_rounded, size: 18),
                SizedBox(width: 6),
                Text('Người làm'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter sheet ──────────────────────────────────────────────────────────
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: BoxDecoration(            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Title
              Row(
                children: [
                  const Icon(Icons.tune_rounded,
                      color: Color(0xFF7B1FA2), size: 22),
                  const SizedBox(width: 8),
                  const Text('Bộ lọc tìm kiếm',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setS(() {
                        _postStatus = 'all';
                        _postJobType = 'all';
                        _workerSort = 'name';
                      });
                      setState(() {
                        _postStatus = 'all';
                        _postJobType = 'all';
                        _workerSort = 'name';
                      });
                    },
                    child: const Text('Đặt lại',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Bài đăng filters ─────────────────────────────────────
              _FilterSection(
                title: 'Trạng thái bài đăng',
                icon: Icons.work_outline_rounded,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in _postStatusOptions.entries)
                      _FilterChip(
                        label: e.value,
                        selected: _postStatus == e.key,
                        onTap: () => setS(() {
                          _postStatus = e.key;
                          setState(() => _postStatus = e.key);
                        }),
                        color: _postStatusColor(e.key),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FilterSection(
                title: 'Loại công việc',
                icon: Icons.schedule_rounded,
                child: Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Tất cả',
                      selected: _postJobType == 'all',
                      onTap: () => setS(() {
                        _postJobType = 'all';
                        setState(() => _postJobType = 'all');
                      }),
                      color: const Color(0xFF7B1FA2),
                    ),
                    _FilterChip(
                      label: 'Full-time',
                      selected: _postJobType == 'full_time',
                      onTap: () => setS(() {
                        _postJobType = 'full_time';
                        setState(() => _postJobType = 'full_time');
                      }),
                      color: const Color(0xFF1565C0),
                    ),
                    _FilterChip(
                      label: 'Part-time',
                      selected: _postJobType == 'part_time',
                      onTap: () => setS(() {
                        _postJobType = 'part_time';
                        setState(() => _postJobType = 'part_time');
                      }),
                      color: const Color(0xFF2E7D32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ─── Người làm filters ────────────────────────────────────
              _FilterSection(
                title: 'Sắp xếp người làm',
                icon: Icons.people_outline_rounded,
                child: Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Tên A–Z',
                      selected: _workerSort == 'name',
                      onTap: () => setS(() {
                        _workerSort = 'name';
                        setState(() => _workerSort = 'name');
                      }),
                      color: const Color(0xFF00695C),
                    ),
                    _FilterChip(
                      label: 'Mới nhất',
                      selected: _workerSort == 'date',
                      onTap: () => setS(() {
                        _workerSort = 'date';
                        setState(() => _workerSort = 'date');
                      }),
                      color: const Color(0xFF00695C),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Apply button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B1FA2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: Get.back,
                  child: const Text('Áp dụng',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasActiveFilter() =>
      _postStatus != 'all' ||
      _postJobType != 'all' ||
      _workerSort != 'name';

  static const _postStatusOptions = {
    'all': 'Tất cả',
    'pending': 'Chờ duyệt',
    'approved': 'Đã duyệt',
    'active': 'Đang tuyển',
    'closed': 'Đã đóng',
    'rejected': 'Từ chối',
  };

  Color _postStatusColor(String s) {
    switch (s) {
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'pending':
        return const Color(0xFFE65100);
      case 'active':
        return const Color(0xFF1565C0);
      case 'closed':
        return Colors.grey;
      case 'rejected':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF7B1FA2);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Bài đăng
// ─────────────────────────────────────────────────────────────────────────────
class _PostsTab extends StatelessWidget {
  const _PostsTab({
    required this.query,
    required this.status,
    required this.jobType,
    required this.uid,
    required this.db,
  });

  final String query;
  final String status;
  final String jobType;
  final String uid;
  final FirebaseFirestore db;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('jobPosts')
          .where('employerId', isEqualTo: uid)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var posts = (snap.data?.docs ?? []).map((d) {
          final data = d.data() as Map<String, dynamic>;
          data['jobId'] = d.id;
          return JobPostModel.fromMap(data);
        }).toList();

        // Lọc theo status
        if (status != 'all') {
          posts = posts.where((p) => p.status == status).toList();
        }
        // Lọc theo jobType
        if (jobType != 'all') {
          posts = posts.where((p) => p.jobType == jobType).toList();
        }
        // Tìm theo query
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          posts = posts
              .where((p) =>
                  p.title.toLowerCase().contains(q) ||
                  p.category.toLowerCase().contains(q) ||
                  (p.description.toLowerCase().contains(q)))
              .toList();
        }

        // Sắp xếp mới nhất trước
        posts.sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

        if (posts.isEmpty) {
          return _emptyState(
            icon: Icons.work_off_outlined,
            title: query.isNotEmpty
                ? 'Không tìm thấy bài đăng'
                : 'Chưa có bài đăng nào',
            sub: query.isNotEmpty
                ? 'Thử tìm kiếm với từ khóa khác'
                : 'Bài đăng của bạn sẽ hiển thị ở đây',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: posts.length,
          itemBuilder: (_, i) => _PostCard(post: posts[i], query: query),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Người làm
// ─────────────────────────────────────────────────────────────────────────────
class _WorkersTab extends StatelessWidget {
  const _WorkersTab({
    required this.query,
    required this.sort,
    required this.uid,
    required this.db,
  });

  final String query;
  final String sort;
  final String uid;
  final FirebaseFirestore db;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('applications')
          .where('employerId', isEqualTo: uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final apps = snap.data?.docs ?? [];
        if (apps.isEmpty) {
          return _emptyState(
            icon: Icons.people_outline_rounded,
            title: 'Chưa có người làm nào',
            sub: 'Người được bạn duyệt sẽ hiển thị ở đây',
          );
        }

        // Lấy danh sách candidateId duy nhất
        final ids = apps
            .map((d) =>
                (d.data() as Map<String, dynamic>)['candidateId'] as String? ??
                '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

        return FutureBuilder<QuerySnapshot>(
          future: db
              .collection('users')
              .where(FieldPath.documentId, whereIn: ids.take(10).toList())
              .get(),
          builder: (ctx2, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            var workers = (userSnap.data?.docs ?? []).map((d) {
              final data = d.data() as Map<String, dynamic>;
              final first = data['firstName'] as String? ?? '';
              final last = data['lastName'] as String? ?? '';
              return _WorkerEntry(
                uid: d.id,
                name: '$first $last'.trim(),
                avatarUrl: data['avatarUrl'] as String?,
                phone: data['phoneNumber'] as String? ?? '',
                rating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
                jobsDone: (data['totalJobsDone'] as int?) ?? 0,
              );
            }).toList();

            // Lọc theo query
            if (query.isNotEmpty) {
              final q = query.toLowerCase();
              workers = workers
                  .where((w) =>
                      w.name.toLowerCase().contains(q) ||
                      w.phone.contains(q))
                  .toList();
            }

            // Sắp xếp
            if (sort == 'name') {
              workers.sort((a, b) => a.name.compareTo(b.name));
            }

            if (workers.isEmpty) {
              return _emptyState(
                icon: Icons.search_off_rounded,
                title: 'Không tìm thấy người làm',
                sub: 'Thử tìm kiếm với tên hoặc số điện thoại khác',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: workers.length,
              itemBuilder: (_, i) =>
                  _WorkerCard(worker: workers[i], query: query),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post card
// ─────────────────────────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.query});

  final JobPostModel post;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Get.toNamed(AppRoutes.postManagement),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.work_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightText(
                          text: post.title,
                          query: query,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _StatusBadge(status: post.status),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              post.jobType == 'full_time'
                                  ? 'Full-time'
                                  : 'Part-time',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.people_outline_rounded,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            '${post.filledSlots}/${post.slots} người',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.attach_money_rounded,
                              size: 13, color: Colors.grey.shade500),
                          Expanded(
                            child: Text(
                              _formatSalary(post.salary, post.salaryType),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (post.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Đăng: ${DateFormat('dd/MM/yyyy').format(post.createdAt!)}',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade400),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade300, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSalary(double salary, String type) {
    final fmt = NumberFormat('#,###', 'vi');
    final s = fmt.format(salary.toInt());
    switch (type) {
      case 'per_hour':
        return '$s đ/giờ';
      case 'per_day':
        return '$s đ/ngày';
      case 'per_month':
        return '$s đ/tháng';
      default:
        return '$s đ';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Worker card
// ─────────────────────────────────────────────────────────────────────────────
class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.worker, required this.query});

  final _WorkerEntry worker;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {}, // TODO: mở profile ứng viên
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00695C), Color(0xFF1565C0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                        color: const Color(0xFF7B1FA2).withOpacity(0.2),
                        width: 2),
                  ),
                  child: worker.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(worker.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _avatarFallback(worker.name)))
                      : _avatarFallback(worker.name),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightText(
                          text: worker.name.isEmpty
                              ? 'Người dùng'
                              : worker.name,
                          query: query,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 3),
                      if (worker.phone.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(worker.phone,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade500)),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Rating stars
                          ...List.generate(
                              5,
                              (i) => Icon(
                                    i < worker.rating.round()
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 14,
                                    color: const Color(0xFFFFC107),
                                  )),
                          const SizedBox(width: 6),
                          Text(
                            '${worker.rating.toStringAsFixed(1)} • ${worker.jobsDone} việc',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade300, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  static const _labels = {
    'pending': 'Chờ duyệt',
    'approved': 'Đã duyệt',
    'active': 'Đang tuyển',
    'closed': 'Đã đóng',
    'rejected': 'Từ chối',
    'draft': 'Nháp',
  };
  static const _colors = {
    'pending': Color(0xFFE65100),
    'approved': Color(0xFF2E7D32),
    'active': Color(0xFF1565C0),
    'closed': Colors.grey,
    'rejected': Color(0xFFC62828),
    'draft': Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? Colors.grey;
    final label = _labels[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// Highlight từ khóa tìm kiếm trong text
class _HighlightText extends StatelessWidget {
  const _HighlightText(
      {required this.text, required this.query, required this.style});
  final String text;
  final String query;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);
    final lower = text.toLowerCase();
    final qLower = query.toLowerCase();
    final idx = lower.indexOf(qLower);
    if (idx < 0) return Text(text, style: style);

    return RichText(
      text: TextSpan(
        children: [
          if (idx > 0)
            TextSpan(
                text: text.substring(0, idx),
                style: style.copyWith(color: Colors.grey.shade700)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: style.copyWith(
              backgroundColor: const Color(0xFF7B1FA2).withOpacity(0.15),
              color: const Color(0xFF7B1FA2),
            ),
          ),
          if (idx + query.length < text.length)
            TextSpan(
                text: text.substring(idx + query.length),
                style: style.copyWith(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

Widget _emptyState(
    {required IconData icon,
    required String title,
    required String sub}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF7B1FA2).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 44, color: const Color(0xFF7B1FA2).withOpacity(0.5)),
          ),
          const SizedBox(height: 18),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF333333))),
          const SizedBox(height: 8),
          Text(sub,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, color: Colors.grey.shade500, height: 1.5)),
        ],
      ),
    ),
  );
}

// ── Filter section ────────────────────────────────────────────────────────────
class _FilterSection extends StatelessWidget {
  const _FilterSection(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : color.withOpacity(0.25), width: 1.2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Worker entry model ────────────────────────────────────────────────────────
class _WorkerEntry {
  final String uid;
  final String name;
  final String? avatarUrl;
  final String phone;
  final double rating;
  final int jobsDone;

  const _WorkerEntry({
    required this.uid,
    required this.name,
    this.avatarUrl,
    required this.phone,
    required this.rating,
    required this.jobsDone,
  });
}
