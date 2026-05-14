import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viecnow/data/models/chat_message.dart';
import 'package:viecnow/data/services/gemini_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _service = GeminiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final List<ChatSession> _sessions = [];
  String? _activeSessionId;
  ChatAttachment? _pendingAttachment;
  bool _isSending = false;
  bool _isLoadingHistory = true;

  static const Color _primary = Color(0xFF2E7D32);
  static const Color _userBubble = Color(0xFF2E7D32);
  static const Color _botBubble = Color(0xFFF1F5F1);
  static const String _sessionsKey = 'chatbot_sessions';

  static const _quickQuestions = [
    '📝 Làm sao viết CV hay?',
    '💼 Ngành nào đang hot?',
    '🎤 Tips phỏng vấn thành công',
    '💰 Mức lương IT ở HCM?',
    '🔄 Cách đổi ngành nghề?',
    '🎓 Sinh viên mới ra trường làm gì?',
  ];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  ChatMessage _botGreeting() {
    return ChatMessage(
      text:
          'Xin chào! Tôi là trợ lý việc làm của ViecNow 👋\n\nTôi có thể giúp bạn:\n• Tư vấn nghề nghiệp\n• Hướng dẫn viết CV\n• Chuẩn bị phỏng vấn\n• Thông tin thị trường lao động\n\nBạn cần hỗ trợ gì hôm nay? 😊',
      role: MessageRole.bot,
      createdAt: DateTime.now(),
    );
  }

  void _addBotGreeting() {
    _messages.add(_botGreeting());
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSessions = prefs.getStringList(_sessionsKey) ?? [];
    final sessions =
        rawSessions
            .map((raw) => jsonDecode(raw))
            .whereType<Map>()
            .map(
              (json) => ChatSession.fromJson(Map<String, dynamic>.from(json)),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (!mounted) return;
    setState(() {
      _sessions
        ..clear()
        ..addAll(sessions);
      if (_sessions.isEmpty) {
        _createNewSession(saveImmediately: false);
      } else {
        _openSession(_sessions.first, closeSheet: false);
      }
      _isLoadingHistory = false;
    });
    if (rawSessions.isEmpty) {
      await _persistSessions();
    }
  }

  Future<void> _persistSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _sessionsKey,
      _sessions.map((session) => jsonEncode(session.toJson())).toList(),
    );
  }

  Future<void> _saveCurrentSession() async {
    final activeId = _activeSessionId;
    if (activeId == null) return;

    final index = _sessions.indexWhere((session) => session.id == activeId);
    if (index < 0) return;

    final userMessages = _messages.where((message) {
      return !message.isTyping && message.role == MessageRole.user;
    }).toList();
    final title = userMessages.isEmpty
        ? 'Đoạn chat mới'
        : _buildSessionTitle(userMessages.first.text);

    _sessions[index] = _sessions[index].copyWith(
      title: title,
      updatedAt: DateTime.now(),
      messages: List<ChatMessage>.from(_messages),
    );
    _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persistSessions();
  }

  String _buildSessionTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Đoạn chat mới';
    return trimmed.length > 34 ? '${trimmed.substring(0, 34)}...' : trimmed;
  }

  void _createNewSession({bool saveImmediately = true}) {
    final now = DateTime.now();
    final session = ChatSession(
      id: now.microsecondsSinceEpoch.toString(),
      title: 'Đoạn chat mới',
      createdAt: now,
      updatedAt: now,
      messages: [_botGreeting()],
    );

    _sessions.insert(0, session);
    _activeSessionId = session.id;
    _pendingAttachment = null;
    _messages
      ..clear()
      ..addAll(session.messages);

    if (saveImmediately) {
      _persistSessions();
    }
    _scrollToBottom();
  }

  void _openSession(ChatSession session, {bool closeSheet = true}) {
    _activeSessionId = session.id;
    _pendingAttachment = null;
    _messages
      ..clear()
      ..addAll(session.messages.isEmpty ? [_botGreeting()] : session.messages);

    if (closeSheet) {
      Navigator.pop(context);
    }
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text, {ChatAttachment? attachment}) async {
    final trimmed = text.trim();
    final selectedAttachment = attachment ?? _pendingAttachment;
    if ((trimmed.isEmpty && selectedAttachment == null) || _isSending) return;

    _controller.clear();
    _pendingAttachment = null;
    // Lưu history trước khi thêm tin nhắn mới (tránh gửi trùng lên Gemini)
    final prevHistory = List<ChatMessage>.from(_messages);
    setState(() {
      _messages.add(
        ChatMessage(
          text: trimmed.isEmpty ? 'Hãy đọc tệp này giúp tôi' : trimmed,
          role: MessageRole.user,
          createdAt: DateTime.now(),
          attachment: selectedAttachment,
        ),
      );
      _messages.add(
        ChatMessage(
          text: '',
          role: MessageRole.bot,
          createdAt: DateTime.now(),
          isTyping: true,
        ),
      );
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(
        prevHistory,
        trimmed,
        attachment: selectedAttachment,
      );
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            text: reply,
            role: MessageRole.bot,
            createdAt: DateTime.now(),
          ),
        );
        _isSending = false;
      });
      await _saveCurrentSession();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            text: '⚠️ ${e.toString().replaceFirst('Exception: ', '')}',
            role: MessageRole.bot,
            createdAt: DateTime.now(),
          ),
        );
        _isSending = false;
      });
      await _saveCurrentSession();
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    if (_isSending) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendingAttachment = ChatAttachment(
        name: picked.name,
        type: ChatAttachmentType.image,
        mimeType: picked.mimeType ?? 'image/jpeg',
        base64Data: base64Encode(bytes),
      );
    });
  }

  Future<void> _pickTextFile() async {
    if (_isSending) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'json', 'csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    final content = utf8.decode(file.bytes!, allowMalformed: true);
    if (!mounted) return;
    setState(() {
      _pendingAttachment = ChatAttachment(
        name: file.name,
        type: ChatAttachmentType.textFile,
        mimeType: 'text/plain',
        textContent: content.length > 12000
            ? '${content.substring(0, 12000)}\n\n[File quá dài nên chỉ gửi 12000 ký tự đầu]'
            : content,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: _buildAppBar(),
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : Column(
              children: [
                Expanded(child: _buildMessageList()),
                _buildQuickQuestions(),
                _buildInputBar(),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF444444)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF43A047), Color(0xFF1E88E5)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trợ lý ViecNow',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Tư vấn việc làm AI',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: Color(0xFF666666)),
          onPressed: _showChatHistory,
          tooltip: 'Lịch sử trò chuyện',
        ),
        IconButton(
          icon: const Icon(
            Icons.add_comment_outlined,
            color: Color(0xFF666666),
          ),
          onPressed: _isSending
              ? null
              : () {
                  setState(() => _createNewSession());
                },
          tooltip: 'Đoạn chat mới',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Color(0xFF888888)),
          onPressed: _isSending
              ? null
              : () async {
                  setState(() {
                    _messages.clear();
                    _addBotGreeting();
                  });
                  await _saveCurrentSession();
                },
          tooltip: 'Xóa cuộc trò chuyện',
        ),
      ],
    );
  }

  void _showChatHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Lịch sử trò chuyện',
                              style: TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isSending
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    setState(() => _createNewSession());
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Chat mới'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _sessions.isEmpty
                          ? const Center(
                              child: Text(
                                'Chưa có lịch sử trò chuyện',
                                style: TextStyle(color: Color(0xFF777777)),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _sessions.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final session = _sessions[index];
                                final isActive = session.id == _activeSessionId;
                                final lastMessage = session.messages
                                    .where((message) => !message.isTyping)
                                    .toList()
                                    .reversed
                                    .firstOrNull;

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isActive
                                        ? _primary
                                        : const Color(0xFFE8F5E9),
                                    child: Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: isActive ? Colors.white : _primary,
                                      size: 19,
                                    ),
                                  ),
                                  title: Text(
                                    session.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isActive
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    lastMessage?.text ?? 'Đoạn chat mới',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: isActive
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: _primary,
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _openSession(session, closeSheet: false);
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildMessageItem(_messages[i]),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    final isUser = msg.role == MessageRole.user;
    final maxWidth = MediaQuery.of(context).size.width * 0.72;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF43A047), Color(0xFF1E88E5)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(maxWidth: maxWidth),
              decoration: BoxDecoration(
                color: isUser ? _userBubble : _botBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: msg.isTyping
                  ? _buildTypingIndicator()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.attachment != null) ...[
                          _buildAttachmentPreview(msg.attachment!, isUser),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          msg.text,
                          style: TextStyle(
                            color: isUser
                                ? Colors.white
                                : const Color(0xFF1A1A1A),
                            fontSize: 14.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(ChatAttachment attachment, bool isUser) {
    final icon = attachment.type == ChatAttachmentType.image
        ? Icons.image_outlined
        : Icons.description_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isUser
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: isUser ? Colors.white : _primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              attachment.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF1A1A1A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return _BouncingDot(delay: Duration(milliseconds: i * 200));
      }),
    );
  }

  Widget _buildQuickQuestions() {
    if (_isSending) return const SizedBox.shrink();
    return Container(
      height: 40,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _quickQuestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () => _sendMessage(_quickQuestions[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Text(
                _quickQuestions[i],
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingAttachment != null) ...[
            _buildPendingAttachment(),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              GestureDetector(
                onTap: _isSending ? null : _showAttachmentOptions,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: _primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 14.5),
                    decoration: const InputDecoration(
                      hintText: 'Hỏi về việc làm...',
                      hintStyle: TextStyle(
                        color: Color(0xFFAAAAAA),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _sendMessage(_controller.text),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _isSending ? const Color(0xFFCCCCCC) : _primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isSending ? Icons.hourglass_top : Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAttachment() {
    final attachment = _pendingAttachment!;
    final icon = attachment.type == ChatAttachmentType.image
        ? Icons.image_outlined
        : Icons.description_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _pendingAttachment = null),
            child: const Icon(
              Icons.close_rounded,
              color: Color(0xFF777777),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined, color: _primary),
                title: const Text('Tải ảnh lên'),
                subtitle: const Text('Cho AI đọc nội dung trong ảnh'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: _primary,
                ),
                title: const Text('Tải file text lên'),
                subtitle: const Text('Hỗ trợ .txt, .md, .json, .csv'),
                onTap: () {
                  Navigator.pop(context);
                  _pickTextFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BouncingDot extends StatefulWidget {
  final Duration delay;
  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween(
      begin: 0.0,
      end: -6.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: const BoxDecoration(
            color: Color(0xFF2E7D32),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
