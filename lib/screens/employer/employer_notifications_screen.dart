import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controller/employer_notification_controller.dart';
import '../../data/models/notification_model.dart';
import '../../routes/app_routes.dart';

class EmployerNotificationsScreen extends StatelessWidget {
  const EmployerNotificationsScreen({super.key});

  // Cấu hình theo type
  static const _typeConfig = {
    'application': _TypeCfg(
      icon: Icons.person_add_rounded,
      bg: Color(0xFF1565C0),
      label: 'Ứng viên',
    ),
    'post_approved': _TypeCfg(
      icon: Icons.check_circle_rounded,
      bg: Color(0xFF2E7D32),
      label: 'Duyệt bài',
    ),
    'post_rejected': _TypeCfg(
      icon: Icons.cancel_rounded,
      bg: Color(0xFFC62828),
      label: 'Từ chối',
    ),
    'message': _TypeCfg(
      icon: Icons.chat_bubble_rounded,
      bg: Color(0xFF7B1FA2),
      label: 'Tin nhắn',
    ),
    'system': _TypeCfg(
      icon: Icons.info_rounded,
      bg: Color(0xFF00695C),
      label: 'Hệ thống',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<EmployerNotificationController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text('Thông báo',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
        actions: [
          Obx(() {
            final hasUnread = ctrl.unreadCount > 0;
            if (!hasUnread) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: ctrl.markAllRead,
              icon: const Icon(Icons.done_all_rounded,
                  color: Colors.white70, size: 18),
              label: const Text('Đọc tất cả',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            );
          }),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (v) {
              if (v == 'clear') ctrl.clearRead();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded,
                        color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Xóa thông báo đã đọc'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Obx(() {
        final list = ctrl.notifications;
        if (list.isEmpty) {
          return _buildEmpty();
        }
        return _buildList(context, ctrl, list);
      }),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF7B1FA2).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 52, color: Color(0xFF7B1FA2)),
          ),
          const SizedBox(height: 20),
          const Text('Chưa có thông báo nào',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF333333))),
          const SizedBox(height: 8),
          Text('Các thông báo về ứng viên, bài đăng\nvà tin nhắn sẽ hiển thị ở đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, color: Colors.grey.shade500, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context,
      EmployerNotificationController ctrl, List<NotificationModel> list) {
    // Nhóm theo ngày
    final grouped = <String, List<NotificationModel>>{};
    for (final n in list) {
      final key = _dayKey(n.createdAt);
      grouped.putIfAbsent(key, () => []).add(n);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nhãn ngày
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
              child: Text(
                entry.key,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.4),
              ),
            ),
            // Danh sách thông báo trong ngày
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              color: Colors.white,
              child: Column(
                children: entry.value.asMap().entries.map((e) {
                  final isLast = e.key == entry.value.length - 1;
                  return _NotifTile(
                    notif: e.value,
                    cfg: _typeConfig[e.value.type] ??
                        _typeConfig['system']!,
                    isLast: isLast,
                    onTap: () => _onTap(context, ctrl, e.value),
                    onDelete: () => ctrl.deleteNotif(e.value.notifId),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  void _onTap(BuildContext context, EmployerNotificationController ctrl,
      NotificationModel n) {
    // Đánh dấu đã đọc
    if (!n.isRead) ctrl.markRead(n.notifId);

    // Điều hướng theo type
    switch (n.type) {
      case 'application':
        Get.toNamed(AppRoutes.employerCandidates);
        break;
      case 'post_approved':
      case 'post_rejected':
        Get.toNamed(AppRoutes.postManagement);
        break;
      case 'message':
        final groupId = n.data['groupId'] as String?;
        if (groupId != null) {
          Get.toNamed(AppRoutes.employerGroups);
        }
        break;
    }
  }

  String _dayKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    if (diff < 7) return '$diff ngày trước';
    return DateFormat('dd/MM/yyyy').format(dt);
  }
}

// ── Tile thông báo ─────────────────────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.notif,
    required this.cfg,
    required this.isLast,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationModel notif;
  final _TypeCfg cfg;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final unread = !notif.isRead;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(16),
            bottom: isLast ? const Radius.circular(16) : Radius.zero,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: unread
                  ? cfg.bg.withOpacity(0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom:
                    isLast ? const Radius.circular(16) : Radius.zero,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon type
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cfg.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(cfg.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: unread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: const Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: cfg.bg, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notif.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: cfg.bg.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cfg.label,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cfg.bg,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(notif.createdAt),
                            style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade400),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: onDelete,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded,
                                  size: 16,
                                  color: Colors.grey.shade400),
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
        if (!isLast)
          Divider(
              height: 1,
              indent: 70,
              endIndent: 14,
              color: Colors.grey.shade100),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return DateFormat('HH:mm dd/MM').format(dt);
  }
}

class _TypeCfg {
  final IconData icon;
  final Color bg;
  final String label;
  const _TypeCfg({required this.icon, required this.bg, required this.label});
}
