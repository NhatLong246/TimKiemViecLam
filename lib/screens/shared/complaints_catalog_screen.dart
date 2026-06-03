import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../common/styles/app_colors.dart';
import '../../controller/login_controller.dart';
import '../../data/models/complaint_catalog_item.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/services/complaints_catalog_service.dart';
import '../../routes/app_routes.dart';

/// Danh mục khiếu nại — gửi đi + nhận về.
class ComplaintsCatalogScreen extends StatefulWidget {
  const ComplaintsCatalogScreen({super.key});

  @override
  State<ComplaintsCatalogScreen> createState() => _ComplaintsCatalogScreenState();
}

class _ComplaintsCatalogScreenState extends State<ComplaintsCatalogScreen>
    with SingleTickerProviderStateMixin {
  final _svc = ComplaintsCatalogService();
  final _auth = Get.find<AuthController>();
  List<ComplaintCatalogItem> _all = [];
  bool _loading = true;
  GroupChatModel? _groupForCreate;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
    final args = Get.arguments;
    if (args is GroupChatModel) {
      _groupForCreate = args;
    } else if (args is Map && args['group'] is GroupChatModel) {
      _groupForCreate = args['group'] as GroupChatModel;
    }
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final u = _auth.currentUser;
    if (u == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      _all = await _svc.fetchForUser(role: u.role, uid: u.id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ComplaintCatalogItem> _filtered(int tabIndex) {
    if (_isEmployer) {
      switch (tabIndex) {
        case 0:
          return _all
              .where((e) => e.direction == ComplaintDirection.received && e.type != ComplaintCatalogType.warning)
              .toList();
        case 1:
          return _all
              .where((e) => e.type == ComplaintCatalogType.warning)
              .toList();
        default:
          return _all;
      }
    }
    switch (tabIndex) {
      case 1:
        return _all
            .where((e) => e.direction == ComplaintDirection.sent)
            .toList();
      case 2:
        return _all
            .where((e) => e.direction == ComplaintDirection.received)
            .toList();
      default:
        return _all;
    }
  }

  bool get _isEmployer => _auth.currentUser?.role == 'employer';
  bool get _isCandidate => _auth.currentUser?.role == 'candidate';
  bool get _isAdmin => _auth.currentUser?.role == 'admin';
  String get _role => _auth.currentUser?.role ?? 'candidate';

  List<String> get _tabLabels {
    if (_isCandidate) {
      return const ['Tất cả', 'Tôi gửi', 'Ca làm của tôi'];
    }
    if (_isEmployer) {
      return const ['Nhận về', 'Cảnh báo'];
    }
    return const ['Tất cả', 'Đã gửi', 'Nhận về'];
  }

  Color get _accent {
    if (_isAdmin) return const Color(0xFF37474F);
    if (_isEmployer) return AppColors.employerPrimary;
    return AppColors.candidatePrimary;
  }

  void _createComplaint() {
    if (_groupForCreate != null && _groupForCreate!.isDissolved) {
      Get.toNamed(
        AppRoutes.postDissolutionComplaint,
        arguments: _groupForCreate,
      );
      return;
    }
    if (_groupForCreate != null && !_groupForCreate!.isDissolved) {
      Get.snackbar(
        'Nhóm chưa giải tán',
        'Khiếu nại chỉ gửi sau khi nhóm công việc đã giải tán.',
      );
      return;
    }
    Get.toNamed(AppRoutes.postDissolutionComplaint);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        title: const Text('Danh mục khiếu nại'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _tabLabels.map((t) => Tab(text: t)).toList(),
        ),
      ),
      floatingActionButton: (_isAdmin || _isEmployer)
          ? null
          : FloatingActionButton.extended(
              onPressed: _createComplaint,
              backgroundColor: _accent,
              icon: const Icon(Icons.add),
              label: const Text('Gửi khiếu nại'),
            ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : Column(
              children: [
                if (!_isAdmin) _buildPurposeBanner(),
                Expanded(
                  child: TabBarView(
              controller: _tabs,
              children: List.generate(_tabLabels.length, (tab) {
                final items = _filtered(tab);
                return RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  _isEmployer
                                      ? (tab == 0
                                          ? 'Chưa có UV khiếu nại về tin đăng của bạn.'
                                          : 'Chưa có cảnh báo nào từ Admin.')
                                      : (tab == 1
                                          ? (_isCandidate
                                              ? 'Chưa khiếu nại về công việc bạn gửi.'
                                              : 'Chưa có khiếu nại bạn gửi.')
                                          : tab == 2
                                              ? (_isCandidate
                                                  ? 'Chưa có khiếu nại về ca làm của bạn.\n'
                                                      'NTD khiếu nại sẽ hiện ở đây.'
                                                  : 'Chưa có khiếu nại nhận về.')
                                              : 'Chưa có khiếu nại.'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                          itemCount: items.length,
                          itemBuilder: (_, i) => _tile(items[i]),
                        ),
                );
              }),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPurposeBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _isCandidate
            ? 'Theo dõi khiếu nại bạn gửi và khiếu nại NTD gửi về ca làm của bạn. '
                'Gửi khiếu nại mới sau khi nhóm công việc đã giải tán.'
            : _isEmployer
                ? 'Theo dõi khiếu nại UV gửi về tin đăng và cảnh báo từ Admin.'
                : 'Tất cả khiếu nại nhân viên và công việc trong hệ thống.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
      ),
    );
  }

  Widget _tile(ComplaintCatalogItem item) {
    final isReceived = item.direction == ComplaintDirection.received;
    final isWarning = item.type == ComplaintCatalogType.warning;

    final color = isWarning
        ? const Color(0xFFD32F2F)
        : isReceived
            ? const Color(0xFFEF6C00)
            : item.type == ComplaintCatalogType.worker
                ? const Color(0xFFC62828)
                : const Color(0xFF1565C0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            isWarning ? Icons.warning_amber_rounded : (isReceived ? Icons.inbox_outlined : Icons.send_outlined),
            color: color,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.headlineForRole(_role),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.directionLabelForRole(_role),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.subtitleForRole(_role),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Text(
              item.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt)} · ${item.status}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
