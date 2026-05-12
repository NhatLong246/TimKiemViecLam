import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _SortOrder { newestFirst, oldestFirst }

enum _FilterType { all, unread, read }

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationCategory category;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.category,
    this.isRead = false,
  });
}

enum NotificationCategory { job, system, promo, profile }

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  _SortOrder _sortOrder = _SortOrder.newestFirst;
  _FilterType _filter = _FilterType.all;

  static const Color _primary = Color(0xFF2E7D32);
  static const Color _unreadBg = Color(0xFFF0F7FF);

  final List<NotificationItem> _notifications = [];

  List<NotificationItem> get _filtered {
    List<NotificationItem> list = List.of(_notifications);
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

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
  }

  void _markRead(NotificationItem item) {
    setState(() => item.isRead = true);
  }

  void _deleteNotification(NotificationItem item) {
    setState(() => _notifications.removeWhere((n) => n.id == item.id));
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
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _notifications.clear());
              Navigator.pop(ctx);
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

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: _buildAppBar(),
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
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF444444)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Thông báo',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_unreadCount',
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
        if (_unreadCount > 0)
          TextButton(
            onPressed: _markAllRead,
            child: const Text(
              'Đọc hết',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (_notifications.isNotEmpty)
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
    return Container(
      color: Colors.white,
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
                  color: selected ? _primary : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF555555),
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
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 18, color: Color(0xFF777777)),
          const SizedBox(width: 6),
          const Text(
            'Sắp xếp:',
            style: TextStyle(fontSize: 13, color: Color(0xFF777777)),
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
                border: Border.all(color: const Color(0xFFCCCCCC)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _sortOrder == _SortOrder.newestFirst
                        ? 'Mới nhất trước'
                        : 'Cũ nhất trước',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
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

  Widget _buildCard(NotificationItem item) {
    final cat = _categoryMeta(item.category);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(item),
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
        onTap: () => _markRead(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead ? Colors.white : _unreadBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isRead
                  ? const Color(0xFFEEEEEE)
                  : const Color(0xFFBBD9FF),
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
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6, top: 4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
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
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: Color(0xFFAAAAAA),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatTime(item.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFAAAAAA),
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
              color: const Color(0xFFF0F4F0),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 40,
              color: Color(0xFFAAAAAA),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không có thông báo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bạn đã xem hết thông báo rồi!',
            style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
          ),
        ],
      ),
    );
  }

  _CategoryMeta _categoryMeta(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.job:
        return _CategoryMeta(
          Icons.work_outline,
          const Color(0xFF1565C0),
          const Color(0xFFE3F2FD),
          'Việc làm',
        );
      case NotificationCategory.system:
        return _CategoryMeta(
          Icons.settings_outlined,
          const Color(0xFF00695C),
          const Color(0xFFE0F2F1),
          'Hệ thống',
        );
      case NotificationCategory.promo:
        return _CategoryMeta(
          Icons.local_offer_outlined,
          const Color(0xFFE65100),
          const Color(0xFFFFF3E0),
          'Khuyến mãi',
        );
      case NotificationCategory.profile:
        return _CategoryMeta(
          Icons.person_outline,
          const Color(0xFF6A1B9A),
          const Color(0xFFF3E5F5),
          'Hồ sơ',
        );
    }
  }
}

class _CategoryMeta {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  const _CategoryMeta(this.icon, this.iconColor, this.bgColor, this.label);
}
