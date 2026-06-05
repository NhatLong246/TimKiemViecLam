import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controller/login_controller.dart';
import '../../controller/messaging_controller.dart';
import '../../utils/messaging_bootstrap.dart';
import '../../data/models/messaging_models.dart';
import 'chat_room_screen.dart';

enum ConversationInboxFilter { all, groupsOnly, directOnly }

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({
    super.key,
    this.isEmployer = false,
    this.embedded = false,
    this.inboxFilter,
  });

  final bool isEmployer;
  /// Nằm trong TabBar (NTD Message) — không vẽ AppBar riêng.
  final bool embedded;
  final ConversationInboxFilter? inboxFilter;

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  late final MessagingController _ctrl;
  final _searchCtrl = TextEditingController();
  int _candidateTabIndex = 1; // 0: nhóm chat, 1: chat cá nhân

  Color get _primary =>
      widget.isEmployer ? const Color(0xFF7B1FA2) : const Color(0xFF2E7D32);

  /// Tab chưa chọn — vàng amber, nổi bật trên gradient xanh (không dùng trắng).
  static const Color _inactiveTabAccent = Color(0xFFFFF176);

  @override
  void initState() {
    super.initState();
    MessagingBootstrap.startIfLoggedIn();
    _ctrl = MessagingBootstrap.ensureController();
    _ctrl.loadInbox();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ConversationThread> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    List<ConversationThread> base;
    if (!widget.isEmployer) {
      base = _ctrl.conversations.where((c) {
        return _candidateTabIndex == 0 ? c.isGroupChat : !c.isGroupChat;
      }).toList();
    } else {
      switch (widget.inboxFilter) {
        case ConversationInboxFilter.groupsOnly:
          base = _ctrl.conversations.where((c) => c.isGroupChat).toList();
          break;
        case ConversationInboxFilter.directOnly:
          base = _ctrl.conversations.where((c) => !c.isGroupChat).toList();
          break;
        default:
          base = _ctrl.conversations.toList();
      }
    }
    if (q.isEmpty) return base;
    return base
        .where(
          (c) =>
              c.peerName.toLowerCase().contains(q) ||
              c.jobTitle.toLowerCase().contains(q) ||
              (c.lastMessageText ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    if (auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tin nhắn')),
        body: const Center(child: Text('Vui lòng đăng nhập để xem tin nhắn')),
      );
    }

    final body = _buildBody(context);

    if (widget.embedded) {
      return ColoredBox(
        color: widget.isEmployer ? Colors.white : const Color(0xFFF2F4F8),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor:
          widget.isEmployer ? Colors.white : const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor:
            widget.isEmployer ? Colors.white : const Color(0xFF2E7D32),
        elevation: widget.isEmployer ? 0 : 1,
        flexibleSpace: widget.isEmployer
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                  ),
                ),
              ),
        title: Obx(() {
          final total = _ctrl.unreadTotal.value;
          return Row(
            children: [
              Text(
                widget.isEmployer ? 'Tin nhắn việc làm' : 'Tin nhắn',
                style: TextStyle(
                  color: widget.isEmployer ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              if (total > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    total > 99 ? '99+' : '$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          );
        }),
        iconTheme: IconThemeData(
          color: widget.isEmployer ? Colors.black87 : Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded),
            tooltip: 'Dọn dẹp tin nhắn lặp lại',
            onPressed: () {
              final auth = Get.find<AuthController>();
              auth.cleanupDuplicateGroups();
            },
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
        children: [
          if (!widget.isEmployer) _buildCandidateTabs(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: !widget.isEmployer && _candidateTabIndex == 1
                      ? 'Tìm theo tên'
                      : 'Tìm theo tên hoặc công việc',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
                      const Color(0xFFF0F2F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_ctrl.isLoading.value && _ctrl.conversations.isEmpty) {
                return Center(
                  child: CircularProgressIndicator(color: _primary),
                );
              }

              final list = _filtered;
              if (list.isEmpty) {
                return _buildEmpty();
              }

              return RefreshIndicator(
                color: _primary,
                onRefresh: _ctrl.loadInbox,
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    widget.isEmployer ? 0 : 4,
                    16,
                    20,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _threadTile(list[i]),
                ),
              );
            }),
          ),
        ],
      );
  }

  Widget _buildCandidateTabs(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _candidateTabIndex = 0),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _candidateTabIndex == 0 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Nhóm chat',
                      style: TextStyle(
                        color: _candidateTabIndex == 0
                            ? const Color(0xFF1A1A1A)
                            : _inactiveTabAccent,
                        fontWeight: _candidateTabIndex == 0
                            ? FontWeight.w700
                            : FontWeight.w600,
                        shadows: _candidateTabIndex == 0
                            ? null
                            : const [
                                Shadow(
                                  color: Color(0x70000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _candidateTabIndex = 1),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _candidateTabIndex == 1 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Chat cá nhân',
                      style: TextStyle(
                        color: _candidateTabIndex == 1
                            ? const Color(0xFF1A1A1A)
                            : _inactiveTabAccent,
                        fontWeight: _candidateTabIndex == 1
                            ? FontWeight.w700
                            : FontWeight.w600,
                        shadows: _candidateTabIndex == 1
                            ? null
                            : const [
                                Shadow(
                                  color: Color(0x70000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                      ),
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

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              widget.isEmployer
                  ? (widget.inboxFilter == ConversationInboxFilter.groupsOnly
                      ? 'Chưa có nhóm chat.\nChấp nhận ứng viên để tạo nhóm làm việc.'
                      : widget.inboxFilter == ConversationInboxFilter.directOnly
                          ? 'Chưa có chat cá nhân.'
                          : 'Chưa có hội thoại.\nChấp nhận ứng viên để bắt đầu trao đổi.')
                  : (_candidateTabIndex == 0
                      ? 'Chưa có nhóm chat.\nNhóm sẽ xuất hiện khi có cuộc hội thoại nhóm.'
                      : 'Chưa có hội thoại.\nSau khi NTD chấp nhận đơn ứng tuyển, bạn có thể nhắn tin tại đây.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _threadTile(ConversationThread thread) {
    final time = thread.lastMessageAt != null
        ? DateFormat('HH:mm').format(thread.lastMessageAt!)
        : '';
    final isGroupTab = widget.isEmployer
        ? widget.inboxFilter == ConversationInboxFilter.groupsOnly
        : _candidateTabIndex == 0;
    final title = thread.listTitle(groupTab: isGroupTab);
    final subtitle = thread.listSubtitle(groupTab: isGroupTab);
    final avatarLetter = thread.listAvatarLetter(groupTab: isGroupTab);
    final hasUnread = thread.unreadCount > 0;

    return InkWell(
      onTap: () async {
        await _ctrl.markConversationRead(thread.groupId);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              groupId: thread.groupId,
              isEmployer: widget.isEmployer,
            ),
          ),
        );
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Xoá cuộc trò chuyện',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                  const Text('Bạn có chắc chắn muốn xoá vĩnh viễn cuộc trò chuyện này không? Thao tác này không thể hoàn tác.', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Huỷ'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _ctrl.deleteConversation(thread.groupId);
                          },
                          child: const Text('Xoá'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(widget.isEmployer ? 0 : 16),
      child: Container(
        margin: EdgeInsets.only(bottom: widget.isEmployer ? 0 : 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: widget.isEmployer
            ? null
            : BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _primary.withValues(alpha: 0.15),
                  backgroundImage: (!isGroupTab && thread.peerAvatarUrl != null)
                      ? NetworkImage(thread.peerAvatarUrl!)
                      : (isGroupTab && thread.groupAvatarBase64 != null)
                          ? MemoryImage(base64Decode(thread.groupAvatarBase64!))
                          : null,
                  child: ((!isGroupTab && thread.peerAvatarUrl == null) ||
                          (isGroupTab && thread.groupAvatarBase64 == null))
                      ? Text(
                          avatarLetter,
                          style: TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                if (hasUnread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: thread.unreadCount > 9 ? 5 : 6,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(minWidth: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        thread.unreadCount > 99
                            ? '99+'
                            : '${thread.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
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
                          title,
                          style: TextStyle(
                            fontWeight:
                                hasUnread ? FontWeight.w800 : FontWeight.w700,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: _primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    thread.lastMessageText ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasUnread
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight:
                          hasUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
