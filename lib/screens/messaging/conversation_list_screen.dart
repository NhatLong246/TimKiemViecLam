import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controller/login_controller.dart';
import '../../controller/messaging_controller.dart';
import '../../data/models/messaging_models.dart';
import 'chat_room_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key, this.isEmployer = false});

  final bool isEmployer;

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  late final MessagingController _ctrl;
  final _searchCtrl = TextEditingController();

  Color get _primary =>
      widget.isEmployer ? const Color(0xFF7B1FA2) : const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(MessagingController());
    _ctrl.bindInboxStream();
    _ctrl.loadInbox();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ConversationThread> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _ctrl.conversations;
    return _ctrl.conversations
        .where(
          (c) =>
              c.peerName.toLowerCase().contains(q) ||
              c.jobTitle.toLowerCase().contains(q),
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.isEmployer ? 'Tin nhắn việc làm' : 'Tin nhắn',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc công việc',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF0F2F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 76,
                    color: Colors.grey.shade200,
                  ),
                  itemBuilder: (_, i) => _threadTile(list[i]),
                ),
              );
            }),
          ),
        ],
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
                  ? 'Chưa có hội thoại.\nChấp nhận ứng viên để bắt đầu trao đổi.'
                  : 'Chưa có hội thoại.\nSau khi NTD chấp nhận đơn ứng tuyển, bạn có thể nhắn tin tại đây.',
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

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              groupId: thread.groupId,
              isEmployer: widget.isEmployer,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _primary.withValues(alpha: 0.15),
              backgroundImage: thread.peerAvatarUrl != null
                  ? NetworkImage(thread.peerAvatarUrl!)
                  : null,
              child: thread.peerAvatarUrl == null
                  ? Text(
                      thread.peerName.isNotEmpty
                          ? thread.peerName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
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
                          thread.peerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
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
                  const SizedBox(height: 2),
                  Text(
                    thread.jobTitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    thread.lastMessageText ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
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
