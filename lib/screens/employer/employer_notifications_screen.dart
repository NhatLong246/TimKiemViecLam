import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../common/styles/app_colors.dart';
import '../../controller/employer_notification_controller.dart';
import '../../data/models/notification_model.dart';
import '../../data/services/group_chat_service.dart';
import '../../routes/app_routes.dart';
import '../../utils/messaging_bootstrap.dart';
import '../messaging/chat_room_screen.dart';

enum _SortOrder { newestFirst, oldestFirst }

enum _FilterType { all, unread, read }

class EmployerNotificationsScreen extends StatefulWidget {
  const EmployerNotificationsScreen({super.key});

  @override
  State<EmployerNotificationsScreen> createState() =>
      _EmployerNotificationsScreenState();
}

class _EmployerNotificationsScreenState
    extends State<EmployerNotificationsScreen> {
  static const Color _primary = AppColors.employerPrimary;
  static const Color _unreadBg = Color(0xFFF5F0FA);

  Color _unreadColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _primary.withValues(alpha: 0.18)
          : _unreadBg;

  _SortOrder _sortOrder = _SortOrder.newestFirst;
  _FilterType _filter = _FilterType.all;

  EmployerNotificationController get _ctrl {
    if (!Get.isRegistered<EmployerNotificationController>()) {
      Get.put(EmployerNotificationController(), permanent: true);
    }
    MessagingBootstrap.startIfLoggedIn();
    return Get.find<EmployerNotificationController>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MessagingBootstrap.startIfLoggedIn();
      _ctrl.refreshNow();
    });
  }

  List<NotificationModel> _filterList(List<NotificationModel> notifications) {
    var list = List<NotificationModel>.from(notifications);
    if (_filter == _FilterType.unread) {
      list = list.where((n) => !n.isRead).toList();
    } else if (_filter == _FilterType.read) {
      list = list.where((n) => n.isRead).toList();
    }
    list.sort(
      (a, b) => _sortOrder == _SortOrder.newestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return list;
  }

  void _deleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Xóa tất cả thông báo?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'Tất cả thông báo sẽ bị xóa vĩnh viễn.',
          style: TextStyle(color: Color(0xFF555555)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () async {
              await _ctrl.deleteAll();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Xóa hết'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua, ${DateFormat('HH:mm').format(dt)}';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<void> _onTap(NotificationModel n) async {
    if (!n.isRead) await _ctrl.markRead(n.notifId);

    switch (n.type) {
      case 'disbursement_approved':
      case 'disbursement_ready':
      case 'job_work_period_ended':
      case 'disbursement_reminder':
        final gid = (n.data['groupId'] ?? '').toString();
        if (gid.isNotEmpty) {
          await _openJobDayEndFlow(gid);
        } else {
          Get.toNamed(AppRoutes.postManagement);
        }
        break;
      case 'disbursement_pending':
      case 'disbursement_rejected':
      case 'group_closed_by_admin':
        final gidPending = (n.data['groupId'] ?? '').toString();
        if (gidPending.isNotEmpty) {
          await _openJobDayEndFlow(gidPending);
        } else {
          Get.snackbar(n.title, n.body);
        }
        break;
      case 'application':
        Get.toNamed(AppRoutes.employerCandidates);
        break;
      case 'post_approved':
      case 'post_rejected':
        Get.toNamed(AppRoutes.postManagement);
        break;
      case 'message':
        final groupId = (n.data['groupId'] ?? '').toString();
        final mc = MessagingBootstrap.ensureController();
        if (groupId.isNotEmpty) {
          await mc.markConversationRead(groupId);
        }
        if (n.notifId.startsWith('chat:')) {
          final gid = n.notifId.substring('chat:'.length);
          if (gid.isNotEmpty) {
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatRoomScreen(
                  groupId: gid,
                  isEmployer: true,
                ),
              ),
            );
            break;
          }
        }
        if (groupId.isNotEmpty) {
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatRoomScreen(
                groupId: groupId,
                isEmployer: true,
              ),
            ),
          );
        } else {
          Get.toNamed(AppRoutes.employerMessages);
        }
        break;
      case 'attendance_result':
        final groupId = (n.data['groupId'] ?? '').toString();
        if (groupId.isNotEmpty) {
          await _openEmployerAttendance(groupId);
        }
        break;
      case 'review':
        Get.toNamed(AppRoutes.employerReviews);
        break;
    }
  }

  Future<void> _openJobDayEndFlow(String groupId) async {
    final g = await GroupChatService().getGroup(groupId);
    if (g == null) {
      Get.snackbar('Lỗi', 'Không tìm thấy nhóm');
      return;
    }
    Get.toNamed(
      AppRoutes.jobDayEndFlow,
      arguments: {
        'group': g,
        'workDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      },
    );
  }

  Future<void> _openEmployerAttendance(String groupId) async {
    final snap = await FirebaseFirestore.instance
        .collection('groupChats')
        .doc(groupId)
        .get();
    if (!snap.exists) {
      Get.snackbar('Lỗi', 'Không tìm thấy nhóm việc làm');
      return;
    }
    final data = snap.data() as Map<String, dynamic>;
    Get.toNamed(
      AppRoutes.attendance,
      arguments: {
        'groupId': groupId,
        'jobId': (data['jobId'] ?? '').toString(),
        'jobTitle': (data['jobTitle'] ?? '').toString(),
        'memberIds': List<String>.from(data['memberIds'] as List? ?? []),
        'employerId': (data['employerId'] ?? '').toString(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _ctrl.unreadBadgeCount.value;
      final notifications = _ctrl.notifications;
      final items = _filterList(notifications);
      final unreadCount = notifications.where((n) => !n.isRead).length;

      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(unreadCount, notifications.isNotEmpty),
        body: Column(
          children: [
            _buildFilterBar(),
            _buildSortBar(),
            Expanded(
              child: items.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _buildCard(items[i]),
                    ),
            ),
          ],
        ),
      );
    });
  }

  PreferredSizeWidget _buildAppBar(int unreadCount, bool hasAny) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () => Get.back(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Thông báo',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (unreadCount > 0)
          TextButton(
            onPressed: _ctrl.markAllRead,
            child: const Text(
              'Đọc hết',
              style: TextStyle(
                color: _primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (hasAny)
          IconButton(
            onPressed: _deleteAll,
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 22,
            ),
            tooltip: 'Xóa tất cả',
          ),
      ],
    );
  }

  Widget _buildFilterBar() {
    const filters = [
      (_FilterType.all, 'Tất cả'),
      (_FilterType.unread, 'Chưa đọc'),
      (_FilterType.read, 'Đã đọc'),
    ];
    final chipBg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: selected ? _primary : chipBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(
            Icons.sort,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            'Sắp xếp:',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              _sortOrder = _sortOrder == _SortOrder.newestFirst
                  ? _SortOrder.oldestFirst
                  : _SortOrder.newestFirst;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _sortOrder == _SortOrder.newestFirst
                        ? 'Mới nhất trước'
                        : 'Cũ nhất trước',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _sortOrder == _SortOrder.newestFirst
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 14,
                    color: _primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(NotificationModel item) {
    final cat = _typeMeta(item.type);
    return Dismissible(
      key: ValueKey(item.notifId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _ctrl.deleteNotif(item.notifId),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text(
              'Xóa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _onTap(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead ? Theme.of(context).cardColor : _unreadColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isRead
                  ? Theme.of(context).dividerColor
                  : _primary.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cat.bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, size: 22, color: cat.iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6, top: 4),
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cat.bgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cat.iconColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatTime(item.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 40,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Không có thông báo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bạn đã xem hết thông báo rồi!',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  _TypeMeta _typeMeta(String type) {
    switch (type) {
      case 'application':
        return _TypeMeta(
          Icons.person_add_rounded,
          const Color(0xFF1565C0),
          const Color(0xFFE3F2FD),
          'Ứng viên',
        );
      case 'post_approved':
        return _TypeMeta(
          Icons.check_circle_outline,
          const Color(0xFF2E7D32),
          const Color(0xFFE8F5E9),
          'Duyệt bài',
        );
      case 'post_rejected':
        return _TypeMeta(
          Icons.cancel_outlined,
          const Color(0xFFC62828),
          const Color(0xFFFFEBEE),
          'Từ chối',
        );
      case 'message':
        return _TypeMeta(
          Icons.chat_bubble_outline,
          _primary,
          const Color(0xFFF3E5F5),
          'Tin nhắn',
        );
      case 'attendance_result':
        return _TypeMeta(
          Icons.fact_check_outlined,
          const Color(0xFF2E7D32),
          const Color(0xFFE8F5E9),
          'Điểm danh',
        );
      case 'review':
        return _TypeMeta(
          Icons.star_outline,
          const Color(0xFFF57F17),
          const Color(0xFFFFF8E1),
          'Đánh giá',
        );
      case 'disbursement_ready':
      case 'job_work_period_ended':
      case 'disbursement_reminder':
        return _TypeMeta(
          Icons.payments_outlined,
          const Color(0xFF6A1B9A),
          const Color(0xFFF3E5F5),
          'Giải ngân',
        );
      case 'disbursement_pending':
      case 'disbursement_approved':
      case 'disbursement_rejected':
        return _TypeMeta(
          Icons.account_balance_wallet_outlined,
          const Color(0xFF1565C0),
          const Color(0xFFE3F2FD),
          'Giải ngân',
        );
      default:
        return _TypeMeta(
          Icons.info_outline,
          const Color(0xFF00695C),
          const Color(0xFFE0F2F1),
          'Hệ thống',
        );
    }
  }
}

class _TypeMeta {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  const _TypeMeta(this.icon, this.iconColor, this.bgColor, this.label);
}
