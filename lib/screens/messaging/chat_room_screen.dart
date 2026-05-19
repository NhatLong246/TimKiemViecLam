import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controller/messaging_controller.dart';
import '../../data/models/messaging_models.dart';
import '../../utils/calendar_helper.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.groupId,
    this.isEmployer = false,
  });

  final String groupId;
  final bool isEmployer;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final MessagingController _ctrl;

  Color get _primary =>
      widget.isEmployer ? const Color(0xFF7B1FA2) : const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<MessagingController>();
    _ctrl.openChatByGroupId(widget.groupId);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _ctrl.closeChat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final thread = _ctrl.activeThread.value;
      if (thread == null) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: CircularProgressIndicator(color: _primary),
          ),
        );
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                thread.peerName,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                thread.jobTitle,
                style: TextStyle(
                  color: _primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(child: _buildMessageList(thread)),
            _buildComposer(thread),
          ],
        ),
      );
    });
  }

  Widget _buildMessageList(ConversationThread thread) {
    final uid = _ctrl.currentUid;
    final items = List<JobChatMessage>.from(_ctrl.messages);

    if (items.isEmpty) {
      return const Center(child: Text('Chưa có tin nhắn'));
    }

    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final msg = items[i];
        if (msg.isSystem) {
          return _systemBubble(msg);
        }
        if (msg.isSchedule) {
          return _scheduleBubble(msg, thread);
        }
        if (msg.isAttendance) {
          return _attendanceBubble(msg);
        }
        return _textBubble(msg, uid);
      },
    );
  }

  Widget _systemBubble(JobChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            msg.content,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ),
      ),
    );
  }

  Widget _textBubble(JobChatMessage msg, String uid) {
    final mine = msg.isMine(uid);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF0084FF) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                color: mine ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            if (msg.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm').format(msg.createdAt!),
                style: TextStyle(
                  fontSize: 10,
                  color: mine ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _attendanceBubble(JobChatMessage msg) {
    final isIn = msg.type == 'attendance_checkin';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isIn ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isIn ? const Color(0xFF4CAF50) : const Color(0xFF1976D2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isIn ? Icons.login_rounded : Icons.logout_rounded,
                color: isIn ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg.content,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleBubble(JobChatMessage msg, ConversationThread thread) {
    final meta = msg.metadata ?? {};
    final date = (meta['date'] ?? '').toString();
    final start = (meta['startTime'] ?? '').toString();
    final end = (meta['endTime'] ?? '').toString();
    final jobTitle = (meta['jobTitle'] ?? thread.jobTitle).toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.88,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primary.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month, color: _primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Lịch ca làm',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(jobTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('$date · $start – $end'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _addToCalendar(meta, jobTitle),
                  icon: const Icon(Icons.event_available, size: 18),
                  label: const Text('Đưa vào lịch'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToCalendar(
    Map<String, dynamic> meta,
    String title,
  ) async {
    final ok = await CalendarHelper.addShiftToDeviceCalendar(
      title: title,
      description: 'Ca làm trên ViecNow',
      dateYmd: (meta['date'] ?? '').toString(),
      startTimeHm: (meta['startTime'] ?? '').toString(),
      endTimeHm: (meta['endTime'] ?? '').toString(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Đã mở ứng dụng lịch để thêm sự kiện' : 'Không thể thêm vào lịch',
        ),
      ),
    );
  }

  Widget _buildComposer(ConversationThread thread) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () => _showActions(thread),
            icon: Icon(Icons.add_circle, color: _primary, size: 28),
          ),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Aa',
                filled: true,
                fillColor: const Color(0xFFF0F2F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _ctrl.isSending.value ? null : _sendText,
            icon: Icon(Icons.send_rounded, color: _primary),
          ),
        ],
      ),
    );
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text;
    if (text.trim().isEmpty) return;
    _textCtrl.clear();
    try {
      await _ctrl.sendText(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _showActions(ConversationThread thread) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Thao tác ca làm',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (!widget.isEmployer) ...[
                  _actionTile(
                    icon: Icons.login_rounded,
                    color: const Color(0xFF2E7D32),
                    title: 'Điểm danh đầu ca',
                    subtitle: 'Ghi nhận giờ vào ca (ứng viên)',
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _runAction(_ctrl.checkIn);
                    },
                  ),
                  _actionTile(
                    icon: Icons.logout_rounded,
                    color: const Color(0xFF1565C0),
                    title: 'Điểm danh cuối ca',
                    subtitle: 'Ghi nhận giờ tan ca',
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _runAction(_ctrl.checkOut);
                    },
                  ),
                ],
                _actionTile(
                  icon: Icons.calendar_month_outlined,
                  color: _primary,
                  title: 'Gửi lịch ca làm',
                  subtitle: widget.isEmployer
                      ? 'NTD phân ca cho ứng viên'
                      : 'Đề xuất / xác nhận lịch',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showScheduleSheet(thread);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _showScheduleSheet(ConversationThread thread) {
    final dateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final startCtrl = TextEditingController(text: '08:00');
    final endCtrl = TextEditingController(text: '17:00');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Lịch ca làm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ngày (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bắt đầu (HH:mm)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kết thúc (HH:mm)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    await _ctrl.sendSchedule(
                      date: dateCtrl.text.trim(),
                      startTime: startCtrl.text.trim(),
                      endTime: endCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Gửi vào hội thoại'),
              ),
            ],
          ),
        );
      },
    );
  }
}
