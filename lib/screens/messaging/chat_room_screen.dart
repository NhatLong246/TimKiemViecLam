import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controller/login_controller.dart';
import '../../controller/messaging_controller.dart';
import '../../utils/messaging_bootstrap.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/models/messaging_models.dart';
import '../../data/services/group_chat_service.dart';
import '../../utils/calendar_helper.dart';
import '../chat/call_screen.dart';
import '../chat/group_management_screen.dart';
import '../attendance/candidate_attendance_screen.dart';
import '../../utils/attendance_capture_helper.dart';
import '../../utils/chat_wallpaper_preferences.dart';
import '../../widgets/attendance_photo_info.dart';
import '../../widgets/chat_conversation_background.dart';
import '../../widgets/chat_wallpaper_picker_sheet.dart';
import '../../widgets/swipe_to_reply.dart';
import 'chat_room_media_mixin.dart';
import 'widgets/job_message_media.dart';
import '../employer/hire_request_sheet.dart';

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

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with ChatRoomMediaMixin {
  @override
  MessagingController get mediaCtrl => _ctrl;

  @override
  Color get mediaPrimary => _primary;

  static const _quickReactions = ['❤️', '😆', '😮', '😢', '😡', '👍'];
  static const _moreEmojis = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '😡',
    '🙏',
    '🔥',
    '👏',
    '🎉',
    '💯',
    '😍',
    '🤔',
    '😎',
    '🥳',
    '😭',
    '🤣',
    '💪',
    '✨',
    '⭐',
  ];

  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _plusLayerLink = LayerLink();
  OverlayEntry? _plusMenuOverlay;
  JobChatMessage? _actionMessage;
  late final MessagingController _ctrl;
  Map<String, String> _nicknames = {};
  StreamSubscription<GroupChatModel?>? _groupNickSub;
  ChatWallpaperConfig _wallpaper = const ChatWallpaperConfig();

  Color get _primary =>
      widget.isEmployer ? const Color(0xFF7B1FA2) : const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _ctrl = MessagingBootstrap.ensureController();
    _ctrl.ensureInboxListening();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ctrl.openChatByGroupId(widget.groupId);
    });
    _groupNickSub = GroupChatService().streamGroup(widget.groupId).listen((g) {
      if (g != null && mounted) {
        setState(() {
          _nicknames = Map<String, String>.from(g.nicknames);
          _wallpaper = g.chatWallpaper;
        });
      }
    });
    _loadWallpaper();
  }

  Future<void> _loadWallpaper() async {
    final cfg = await ChatWallpaperPreferences.loadForGroup(widget.groupId);
    if (mounted) setState(() => _wallpaper = cfg);
  }

  @override
  void dispose() {
    _groupNickSub?.cancel();
    _hidePlusMenu();
    disposeMedia();
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
        final err = _ctrl.errorMessage.value.trim();
        return Scaffold(
          appBar: AppBar(title: const Text('Tin nhắn')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (err.isNotEmpty) ...[
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      err,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _ctrl.openChatByGroupId(widget.groupId),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                      style: FilledButton.styleFrom(backgroundColor: _primary),
                    ),
                  ] else
                    CircularProgressIndicator(color: _primary),
                ],
              ),
            ),
          ),
        );
      }

      return PopScope(
        canPop: _actionMessage == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _actionMessage != null) {
            _closeMessageActions();
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: widget.isEmployer ? Colors.white : _primary,
            flexibleSpace: widget.isEmployer
                ? null
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                      ),
                    ),
                  ),
            elevation: widget.isEmployer ? 0.5 : 0,
            iconTheme: IconThemeData(
              color: widget.isEmployer ? Colors.black87 : Colors.white,
            ),
            title: _buildAppBarTitle(thread),
            actions: [
              if (widget.isEmployer && !thread.isGroupChat)
                _topAction(
                  Icons.handshake_outlined,
                  () => _openHireRequest(thread),
                  forEmployer: true,
                ),
              _topAction(
                Icons.call_outlined,
                () => _startCall(thread, isVideo: false),
                forEmployer: widget.isEmployer,
              ),
              _topAction(
                Icons.videocam_outlined,
                () => _startCall(thread, isVideo: true),
                forEmployer: widget.isEmployer,
              ),
              if (thread.isGroupChat)
                _topAction(
                  Icons.menu,
                  () => _openGroupManagement(thread),
                  forEmployer: widget.isEmployer,
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              ChatConversationBackground(
                config: _wallpaper,
                isCandidateTheme: !widget.isEmployer,
              ),
              Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        _buildMessageList(
                          thread,
                          dimmed: _actionMessage != null,
                        ),
                        if (_actionMessage != null)
                          _buildMessageActionOverlay(thread),
                      ],
                    ),
                  ),
                  if (_actionMessage == null)
                    (isRecording ? buildRecordingBar() : _buildComposer(thread))
                  else
                    _buildMessageActionToolbar(thread),
                ],
              ),
              buildUploadOverlay(),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMessageList(ConversationThread thread, {bool dimmed = false}) {
    final uid = _ctrl.currentUid;
    final items = List<JobChatMessage>.from(_ctrl.messages);

    if (items.isEmpty) {
      return const Center(child: Text('Chưa có tin nhắn'));
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollCtrl,
          reverse: true,
          physics: dimmed
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final msg = items[i];
            if (dimmed && _actionMessage?.msgId == msg.msgId) {
              return const SizedBox.shrink();
            }

            Widget tile;
            if (msg.isSystem) {
              tile = _systemBubble(msg);
            } else if (msg.isSchedule) {
              tile = _scheduleBubble(msg, thread);
            } else if (msg.isAttendanceRequest) {
              tile = _attendanceRequestBubble(msg, thread, uid);
            } else if (msg.isAttendance) {
              tile = _attendanceBubble(msg);
            } else if (msg.isCall) {
              tile = _callBubble(msg, thread);
            } else if (msg.isImage ||
                msg.isAudio ||
                msg.isFile ||
                msg.isLocation) {
              tile = _mediaMessageTile(msg, uid, thread);
            } else {
              tile = _textBubble(msg, uid, thread);
            }

            if (!dimmed) return tile;
            return Opacity(opacity: 0.35, child: tile);
          },
        ),
      ],
    );
  }

  Widget _systemBubble(JobChatMessage msg) {
    final accent = widget.isEmployer
        ? const Color(0xFF7B1FA2)
        : const Color(0xFF2E7D32);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.12),
                accent.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  msg.content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _senderName(String senderId, ConversationThread thread) {
    final nick = _nicknames[senderId];
    if (nick != null && nick.trim().isNotEmpty) return nick.trim();
    final p = _ctrl.participantFor(senderId);
    if (p != null && p.name.isNotEmpty) return p.name;
    if (senderId == thread.peerId) return thread.peerName;
    return 'Thành viên';
  }

  Widget _mediaMessageTile(
    JobChatMessage msg,
    String uid,
    ConversationThread thread, {
    bool dimmed = false,
  }) {
    final mine = msg.isMine(uid);
    final isGroup = thread.isGroupChat;
    final senderName = _senderName(msg.senderId, thread);
    final senderAvatar = _senderAvatarUrl(msg.senderId, thread);

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _openMessageActions(msg, thread, uid),
      child: JobMediaMessageBubble(
        msg: msg,
        isMine: mine,
        primary: _primary,
        senderName: senderName,
        avatar: _messageAvatar(name: senderName, avatarUrl: senderAvatar),
        showSenderName: isGroup && !mine,
        messageWrapper: (body) =>
            _wrapSwipeToReply(msg: msg, uid: uid, alignEnd: mine, child: body),
      ),
    );

    if (!dimmed) return tile;
    return Opacity(opacity: 0.35, child: tile);
  }

  String? _senderAvatarUrl(String senderId, ConversationThread thread) {
    final p = _ctrl.participantFor(senderId);
    if (p?.avatarUrl != null && p!.avatarUrl!.isNotEmpty) return p.avatarUrl;
    if (senderId == thread.peerId) return thread.peerAvatarUrl;
    return null;
  }

  Widget _textBubble(
    JobChatMessage msg,
    String uid,
    ConversationThread thread,
  ) {
    final mine = msg.isMine(uid);
    final isGroup = thread.isGroupChat;
    final senderName = _senderName(msg.senderId, thread);
    final senderAvatar = _senderAvatarUrl(msg.senderId, thread);
    final isFocused = _actionMessage?.msgId == msg.msgId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            _messageAvatar(name: senderName, avatarUrl: senderAvatar),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: _wrapSwipeToReply(
              msg: msg,
              uid: uid,
              alignEnd: mine,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!mine && isGroup)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: () => _openMessageActions(msg, thread, uid),
                    child: _messageBubbleContent(
                      msg: msg,
                      mine: mine,
                      uid: uid,
                      thread: thread,
                      elevated: isFocused,
                    ),
                  ),
                  if (msg.reactionCounts.isNotEmpty)
                    _reactionStrip(msg, mine, thread),
                ],
              ),
            ),
          ),
          if (mine) ...[
            const SizedBox(width: 8),
            _messageAvatar(name: senderName, avatarUrl: senderAvatar),
          ],
        ],
      ),
    );
  }

  Widget _messageBubbleContent({
    required JobChatMessage msg,
    required bool mine,
    required String uid,
    required ConversationThread thread,
    bool elevated = false,
  }) {
    final reply = msg.metadata?['replyTo'];
    Map<String, dynamic>? replyMap;
    if (reply is Map) {
      replyMap = Map<String, dynamic>.from(reply);
    }

    final maxBubbleW = MediaQuery.of(context).size.width * 0.72;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxBubbleW),
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? const Color(0xFF0084FF) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: elevated
                    ? Colors.black.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: elevated ? 12 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (replyMap != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mine
                        ? Colors.white.withValues(alpha: 0.15)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: mine ? Colors.white70 : _primary,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    (replyMap['content'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: mine ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
              Text(
                msg.content,
                style: TextStyle(
                  color: msg.isRecalled
                      ? (mine ? Colors.white70 : Colors.black45)
                      : (mine
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface),
                  fontSize: 15,
                  height: 1.35,
                  fontStyle: msg.isRecalled
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
              if (msg.createdAt != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    DateFormat('HH:mm').format(msg.createdAt!),
                    style: TextStyle(
                      fontSize: 10,
                      color: mine ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _reactionStrip(
    JobChatMessage msg,
    bool mine,
    ConversationThread thread,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: 4, left: mine ? 0 : 4, right: mine ? 4 : 0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: mine ? WrapAlignment.end : WrapAlignment.start,
        children: msg.reactionCounts.entries.map((e) {
          final highlighted = msg.reactionBy(_ctrl.currentUid) == e.key;
          return GestureDetector(
            onTap: () =>
                _showReactionDetailsSheet(msg, thread, initialEmoji: e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: highlighted
                    ? _primary.withValues(alpha: 0.12)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: highlighted ? _primary : Colors.grey.shade300,
                ),
              ),
              child: Text(
                '${e.key} ${e.value}',
                style: TextStyle(
                  fontSize: 12,
                  color: highlighted
                      ? _primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showReactionDetailsSheet(
    JobChatMessage msg,
    ConversationThread thread, {
    String? initialEmoji,
  }) {
    if (msg.reactions.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        var filterEmoji = initialEmoji;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final uid = _ctrl.currentUid;
            final allEntries = msg.reactions.entries.toList();
            final filtered = filterEmoji == null
                ? allEntries
                : allEntries.where((e) => e.value == filterEmoji).toList();

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Cảm xúc',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF3A3A3C)),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          indent: 72,
                          color: Color(0xFF3A3A3C),
                        ),
                        itemBuilder: (_, i) {
                          final entry = filtered[i];
                          final userId = entry.key;
                          final emoji = entry.value;
                          final isMe = userId == uid;
                          final name = _senderName(userId, thread);
                          final avatarUrl = _senderAvatarUrl(userId, thread);

                          return InkWell(
                            onTap: isMe
                                ? () async {
                                    Navigator.pop(sheetCtx);
                                    try {
                                      await _ctrl.toggleReaction(
                                        msg.msgId,
                                        emoji,
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e.toString().replaceFirst(
                                                'Exception: ',
                                                '',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  _messageAvatar(
                                    name: name,
                                    avatarUrl: avatarUrl,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (isMe)
                                          Text(
                                            'Nhấn để gỡ',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF3A3A3C)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _reactionFilterChip(
                              label: 'TẤT CẢ',
                              selected: filterEmoji == null,
                              onTap: () =>
                                  setSheetState(() => filterEmoji = null),
                            ),
                            const SizedBox(width: 8),
                            ...msg.reactionCounts.entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _reactionFilterChip(
                                  label: '${e.key} ${e.value}',
                                  selected: filterEmoji == e.key,
                                  onTap: () =>
                                      setSheetState(() => filterEmoji = e.key),
                                ),
                              );
                            }),
                          ],
                        ),
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

  Widget _reactionFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFF3A3A3C) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.2)
                  : const Color(0xFF3A3A3C),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade400,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  bool _canOpenMessageActions(JobChatMessage msg) {
    if (msg.isSystem ||
        msg.isAttendance ||
        msg.isAttendanceRequest ||
        msg.isSchedule ||
        msg.isCall) {
      return false;
    }
    return true;
  }

  Widget _wrapSwipeToReply({
    required JobChatMessage msg,
    required String uid,
    required bool alignEnd,
    required Widget child,
  }) {
    if (!_canOpenMessageActions(msg) || msg.isRecalled) return child;
    return SwipeToReply(
      alignEnd: alignEnd,
      iconColor: _primary,
      onReply: () => _ctrl.setReply(msg),
      child: child,
    );
  }

  String? _copyableText(JobChatMessage msg) {
    final text = msg.content.trim();
    if (text.isNotEmpty) return text;
    if (msg.isImage) return '[Hình ảnh]';
    if (msg.isAudio) return '[Tin thoại]';
    if (msg.isFile) return '[Tệp đính kèm]';
    if (msg.isLocation) return '[Vị trí]';
    return null;
  }

  void _openMessageActions(
    JobChatMessage msg,
    ConversationThread thread,
    String uid,
  ) {
    if (!_canOpenMessageActions(msg)) return;
    HapticFeedback.mediumImpact();
    _hidePlusMenu();
    setState(() => _actionMessage = msg);
  }

  void _closeMessageActions() {
    setState(() => _actionMessage = null);
  }

  Future<void> _pickReaction(String emoji) async {
    final msg = _actionMessage;
    if (msg == null) return;
    try {
      await _ctrl.toggleReaction(msg.msgId, emoji);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
    _closeMessageActions();
  }

  Widget _buildMessageActionOverlay(ConversationThread thread) {
    final msg = _actionMessage!;
    final uid = _ctrl.currentUid;
    final mine = msg.isMine(uid);
    final senderName = _senderName(msg.senderId, thread);
    final senderAvatar = _senderAvatarUrl(msg.senderId, thread);

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: GestureDetector(
          onTap: _closeMessageActions,
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {},
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: mine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      _buildReactionPickerBar(),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!mine) ...[
                            _messageAvatar(
                              name: senderName,
                              avatarUrl: senderAvatar,
                            ),
                            const SizedBox(width: 8),
                          ],
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.72,
                            ),
                            child: _messageBubbleContent(
                              msg: msg,
                              mine: mine,
                              uid: uid,
                              thread: thread,
                              elevated: true,
                            ),
                          ),
                          if (mine) ...[
                            const SizedBox(width: 8),
                            _messageAvatar(
                              name: senderName,
                              avatarUrl: senderAvatar,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionPickerBar() {
    final maxW = MediaQuery.of(context).size.width - 48;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Material(
        color: const Color(0xFF3A3A3C),
        elevation: 8,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              ..._quickReactions.map(_reactionPickerEmoji),
              _reactionPickerMoreButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reactionPickerEmoji(String emoji) {
    return InkWell(
      onTap: () => _pickReaction(emoji),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(emoji, style: const TextStyle(fontSize: 24, height: 1.1)),
      ),
    );
  }

  Widget _reactionPickerMoreButton() {
    return InkWell(
      onTap: _showExtendedEmojiPicker,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  void _showExtendedEmojiPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _moreEmojis.map((e) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickReaction(e);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageActionToolbar(ConversationThread thread) {
    final msg = _actionMessage!;
    final uid = _ctrl.currentUid;
    final mine = msg.isMine(uid);
    final copyText = _copyableText(msg);
    final canReply = !msg.isRecalled;

    return Material(
      color: const Color(0xFF2C2C2E),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _toolbarAction(
                icon: Icons.reply_rounded,
                label: 'Trả lời',
                color: const Color(0xFF42A5F5),
                onTap: canReply
                    ? () {
                        _ctrl.setReply(msg);
                        _closeMessageActions();
                      }
                    : null,
              ),
              _toolbarAction(
                icon: Icons.copy_rounded,
                label: 'Sao chép',
                color: const Color(0xFF42A5F5),
                onTap: copyText != null
                    ? () {
                        Clipboard.setData(ClipboardData(text: copyText));
                        _closeMessageActions();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    : null,
              ),
              _toolbarAction(
                icon: Icons.delete_outline_rounded,
                label: 'Xóa',
                color: const Color(0xFFEF5350),
                onTap: mine && !msg.isRecalled
                    ? () => _confirmDeleteMessage(msg)
                    : null,
              ),
              _toolbarAction(
                icon: Icons.more_horiz_rounded,
                label: 'Khác',
                color: const Color(0xFF42A5F5),
                onTap: () => _showMoreMessageActions(msg, mine),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarAction({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMessage(JobChatMessage msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tin nhắn'),
        content: const Text('Tin nhắn sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _ctrl.deleteMessage(msg.msgId);
      _closeMessageActions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _showMoreMessageActions(JobChatMessage msg, bool mine) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mine && msg.isText && !msg.isRecalled)
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: _primary),
                  title: const Text('Sửa tin nhắn'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditMessageDialog(msg);
                  },
                ),
              if (mine && !msg.isRecalled)
                ListTile(
                  leading: const Icon(
                    Icons.undo_rounded,
                    color: Color(0xFF7B1FA2),
                  ),
                  title: const Text('Thu hồi'),
                  subtitle: const Text('Ẩn nội dung với mọi người'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _recallMessage(msg);
                  },
                ),
              ListTile(
                leading: Icon(Icons.push_pin_outlined, color: _primary),
                title: const Text('Ghim tin nhắn'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pinMessage(msg);
                },
              ),
              ListTile(
                leading: Icon(Icons.flag_outlined, color: _primary),
                title: const Text('Báo cáo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _closeMessageActions();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Đã ghi nhận phản hồi. Quản trị sẽ xem xét.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pinMessage(JobChatMessage msg) async {
    try {
      await _ctrl.pinMessage(msg.msgId);
      _closeMessageActions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã ghim tin nhắn'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _recallMessage(JobChatMessage msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi tin nhắn'),
        content: const Text(
          'Mọi người trong nhóm sẽ thấy "Tin nhắn đã được thu hồi".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _ctrl.recallMessage(msg.msgId);
      _closeMessageActions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _showEditMessageDialog(JobChatMessage msg) {
    final editCtrl = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa tin nhắn'),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Nội dung tin nhắn',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final text = editCtrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _ctrl.editMessage(msg.msgId, text);
                _closeMessageActions();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Widget _messageAvatar({required String name, String? avatarUrl}) {
    final hasUrl = avatarUrl != null && avatarUrl.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    if (hasUrl) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    final colorIndex = name.isNotEmpty
        ? name.codeUnits.reduce((a, b) => a + b) % 5
        : 0;
    const palettes = [
      [Color(0xFF66BB6A), Color(0xFF2E7D32)],
      [Color(0xFF42A5F5), Color(0xFF1565C0)],
      [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
      [Color(0xFFFFB74D), Color(0xFFE65100)],
      [Color(0xFF4DB6AC), Color(0xFF00695C)],
    ];
    final pair = palettes[colorIndex];

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: pair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _attendanceBubble(JobChatMessage msg) {
    final isIn = msg.type == 'attendance_checkin';
    final meta = msg.metadata ?? {};
    final photoB64 = (meta['photoBase64'] ?? msg.attachmentUrl ?? '')
        .toString();
    final capturedAt = (meta['capturedAt'] ?? '').toString();
    final locationLabel = (meta['locationLabel'] ?? '').toString();
    final fileName = (meta['photoFileName'] ?? '').toString();
    final accent = isIn ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isIn ? Icons.login_rounded : Icons.logout_rounded,
                    color: accent,
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
              if (photoB64.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(photoB64),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ],
              AttendancePhotoInfo(
                capturedAt: capturedAt.isNotEmpty ? capturedAt : null,
                locationLabel: locationLabel.isNotEmpty ? locationLabel : null,
                fileName: fileName.isNotEmpty ? fileName : null,
                textColor: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attendanceRequestBubble(
    JobChatMessage msg,
    ConversationThread thread,
    String uid,
  ) {
    final meta = msg.metadata ?? {};
    final targetId = (meta['targetUserId'] ?? '').toString();
    final phase = (meta['phase'] ?? 'check_in').toString();
    final isCheckIn = phase == 'check_in';
    final isForMe = !widget.isEmployer && targetId == uid;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFB300)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                    color: const Color(0xFFF57C00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      msg.content,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              if (isForMe) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openCandidateAttendance(thread),
                    icon: const Icon(Icons.fact_check_rounded),
                    label: const Text('Mở màn điểm danh'),
                    style: FilledButton.styleFrom(backgroundColor: _primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCandidateAttendance(ConversationThread thread) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('groupChats')
          .doc(thread.groupId)
          .get();
      if (!snap.exists) return;
      final group = GroupChatModel.fromMap(snap.data()!, snap.id);
      await Get.to(
        () => CandidateAttendanceScreen(group: group),
        transition: Transition.rightToLeft,
      );
    } catch (_) {}
  }

  // ignore: unused_element
  Future<void> _captureAttendancePhoto({
    required String attendanceId,
    required bool isCheckIn,
    required String expectedStartTime,
  }) async {
    if (attendanceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phiên điểm danh không hợp lệ')),
      );
      return;
    }
    final cam = await Permission.camera.request();
    if (!cam.isGranted) return;
    await Permission.location.request();

    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 55,
      maxWidth: 900,
      maxHeight: 900,
    );
    if (picked == null || !mounted) return;

    final captureMeta = await AttendanceCaptureHelper.buildMeta(
      candidateId: Get.find<AuthController>().currentUser?.id ?? '',
      isCheckIn: isCheckIn,
      imagePath: picked.path,
    );

    final bytes = await File(picked.path).readAsBytes();
    if (bytes.lengthInBytes > 700 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ảnh quá lớn, chụp lại gần hơn')),
      );
      return;
    }

    final b64 = base64Encode(bytes);
    try {
      await _ctrl.submitAttendancePhotoFromRequest(
        attendanceId: attendanceId,
        isCheckIn: isCheckIn,
        photoBase64: b64,
        expectedStartTime: expectedStartTime,
        captureMeta: captureMeta,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCheckIn
                ? 'Đã gửi ảnh điểm danh đầu ca'
                : 'Đã gửi ảnh điểm danh cuối ca',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
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
            color: Theme.of(context).cardColor,
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
                    'Phân công công việc',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                jobTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
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

  Future<void> _addToCalendar(Map<String, dynamic> meta, String title) async {
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
          ok
              ? 'Đã mở ứng dụng lịch để thêm sự kiện'
              : 'Không thể thêm vào lịch',
        ),
      ),
    );
  }

  Widget _buildComposer(ConversationThread thread) {
    return Obx(() {
      final reply = _ctrl.replyTo.value;
      return Container(
        color: Theme.of(context).cardColor,
        padding: EdgeInsets.fromLTRB(
          8,
          reply != null ? 0 : 8,
          8,
          8 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reply != null)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  border: Border(left: BorderSide(color: _primary, width: 3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trả lời ${_ctrl.replySenderName(reply)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                          Text(
                            reply.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _ctrl.clearReply,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CompositedTransformTarget(
                  link: _plusLayerLink,
                  child: _bottomAction(Icons.add, _togglePlusMenu),
                ),
                const SizedBox(width: 4),
                _bottomAction(Icons.camera_alt_outlined, takePhotoAndSend),
                const SizedBox(width: 4),
                _bottomAction(Icons.mic_none_rounded, startRecording),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Nhắn tin...',
                      filled: true,
                      fillColor:
                          Theme.of(context).inputDecorationTheme.fillColor ??
                          const Color(0xFFF0F2F5),
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
                const SizedBox(width: 6),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    onPressed: _ctrl.isSending.value ? null : _sendText,
                    icon: const Icon(
                      Icons.send_rounded,
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
    });
  }

  Future<void> _startCall(
    ConversationThread thread, {
    required bool isVideo,
  }) async {
    _hidePlusMenu();
    _closeMessageActions();

    final callColor = isVideo
        ? const Color(0xFF1565C0)
        : const Color(0xFF2E7D32);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isVideo
                      ? const [Color(0xFF1565C0), Color(0xFF42A5F5)]
                      : const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isVideo ? 'Gọi video' : 'Gọi thoại',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Một tin nhắn sẽ được gửi vào hội thoại để thành viên khác có thể tham gia.',
          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: callColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: Icon(
              isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
              color: Colors.white,
              size: 16,
            ),
            label: Text(
              isVideo ? 'Gọi video' : 'Gọi thoại',
              style: const TextStyle(color: Colors.white),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final result = await _ctrl.startCall(isVideo: isVideo);
      if (!mounted) return;

      final auth = Get.find<AuthController>().currentUser;
      final userName = '${auth?.firstName ?? ''} ${auth?.lastName ?? ''}'
          .trim();

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CallScreen(
            isVideo: isVideo,
            groupName: thread.isGroupChat ? thread.jobTitle : thread.peerName,
            userName: userName.isNotEmpty ? userName : 'Người dùng',
            userId: auth?.id ?? _ctrl.currentUid,
            callId: result.roomUrl,
            onCallEnded: () => _ctrl.endCall(result.msgId),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _joinCall({
    required JobChatMessage msg,
    required ConversationThread thread,
    required bool isVideo,
    required String roomUrl,
  }) {
    final auth = Get.find<AuthController>().currentUser;
    final userName = '${auth?.firstName ?? ''} ${auth?.lastName ?? ''}'.trim();
    final callerName = _senderName(msg.senderId, thread);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CallScreen(
          isVideo: isVideo,
          groupName: callerName,
          userName: userName.isNotEmpty ? userName : 'Người dùng',
          userId: auth?.id ?? _ctrl.currentUid,
          callId: roomUrl,
          onCallEnded: msg.senderId == _ctrl.currentUid
              ? () => _ctrl.endCall(msg.msgId)
              : null,
        ),
      ),
    );
  }

  Widget _callBubble(JobChatMessage msg, ConversationThread thread) {
    final meta = msg.metadata ?? {};
    final isVideo = meta['isVideo'] == true;
    final roomUrl = (meta['roomUrl'] ?? '').toString();
    final status = (meta['status'] ?? 'ongoing').toString();
    final isOngoing = status == 'ongoing';
    final callColor = isVideo
        ? const Color(0xFF1565C0)
        : const Color(0xFF2E7D32);
    final callLight = isVideo
        ? const Color(0xFFE3F2FD)
        : const Color(0xFFE8F5E9);
    final callerName = _senderName(msg.senderId, thread);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.88,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isOngoing
                  ? callColor.withValues(alpha: 0.35)
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isOngoing
                        ? [callColor, callColor.withValues(alpha: 0.75)]
                        : [Colors.grey.shade400, Colors.grey.shade300],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(17),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOngoing
                          ? (isVideo
                                ? Icons.videocam_rounded
                                : Icons.phone_rounded)
                          : (isVideo
                                ? Icons.videocam_off_rounded
                                : Icons.phone_missed_rounded),
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            isOngoing ? 'Đang diễn ra' : 'Đã kết thúc',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (msg.createdAt != null)
                      Text(
                        DateFormat('HH:mm').format(msg.createdAt!),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: callLight,
                          child: Text(
                            callerName.isNotEmpty
                                ? callerName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: callColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$callerName đã bắt đầu cuộc gọi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isOngoing && roomUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: callColor,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: Icon(
                            isVideo
                                ? Icons.videocam_rounded
                                : Icons.phone_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isVideo
                                ? 'Tham gia video call'
                                : 'Tham gia cuộc gọi',
                          ),
                          onPressed: () => _joinCall(
                            msg: msg,
                            thread: thread,
                            isVideo: isVideo,
                            roomUrl: roomUrl,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topAction(
    IconData icon,
    VoidCallback onTap, {
    bool forEmployer = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: forEmployer
            ? _primary.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: forEmployer ? _primary : Colors.white),
      ),
    );
  }

  void _openHireRequest(ConversationThread thread) {
    final candidateId = thread.candidateId?.isNotEmpty == true
        ? thread.candidateId!
        : thread.peerId;
    if (candidateId.isEmpty) {
      Get.snackbar(
        'Lỗi',
        'Không xác định được người làm trong cuộc trò chuyện.',
      );
      return;
    }
    showHireRequestSheet(
      context: context,
      candidateId: candidateId,
      candidateName: thread.peerName.isEmpty ? 'Người làm' : thread.peerName,
    );
  }

  Widget _bottomAction(IconData icon, VoidCallback onTap) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: const Color(0xFF607080)),
      ),
    );
  }

  void _togglePlusMenu() {
    if (_plusMenuOverlay != null) {
      _hidePlusMenu();
    } else {
      _showComposerPlusMenu();
    }
  }

  void _hidePlusMenu() {
    _plusMenuOverlay?.remove();
    _plusMenuOverlay = null;
  }

  /// Menu bám ngay trên nút + (ảnh, file, vị trí, hình nền chat 1-1).
  void _showComposerPlusMenu() {
    if (!mounted || _plusMenuOverlay != null) return;

    final isGroup = _ctrl.activeThread.value?.isGroupChat ?? false;

    _plusMenuOverlay = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hidePlusMenu,
                child: Container(color: Colors.black.withValues(alpha: 0.25)),
              ),
            ),
            CompositedTransformFollower(
              link: _plusLayerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.bottomLeft,
              offset: const Offset(0, -8),
              child: Material(
                color: Colors.white,
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: 200,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _plusMenuRow(
                        label: 'Thư viện ảnh',
                        icon: Icons.image_outlined,
                        onTap: () {
                          _hidePlusMenu();
                          pickGalleryAndSend();
                        },
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                      _plusMenuRow(
                        label: 'File',
                        icon: Icons.attach_file_rounded,
                        onTap: () {
                          _hidePlusMenu();
                          pickFileAndSend();
                        },
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                      _plusMenuRow(
                        label: 'Vị trí',
                        icon: Icons.near_me_rounded,
                        onTap: () {
                          _hidePlusMenu();
                          sendLocationMessage();
                        },
                      ),
                      if (!isGroup) ...[
                        Divider(height: 1, color: Colors.grey.shade200),
                        _plusMenuRow(
                          label: 'Hình nền',
                          icon: Icons.wallpaper_outlined,
                          onTap: () {
                            _hidePlusMenu();
                            _openWallpaperPicker();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_plusMenuOverlay!);
  }

  Widget _plusMenuRow({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isEmployer
                      ? const [Color(0xFF7B1FA2), Color(0xFFAB47BC)]
                      : const [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF212121),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(ConversationThread thread) {
    final titleStyle = TextStyle(
      color: widget.isEmployer ? Colors.black87 : Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final subtitleStyle = TextStyle(
      color: widget.isEmployer ? _primary : Colors.white70,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    // Chat cá nhân: tên đối phương.
    if (!thread.isGroupChat) {
      return Text(thread.peerName, style: titleStyle);
    }

    // Nhóm chat: tiêu đề = tên việc (giống user), không lấy tên 1 nhân viên ngẫu nhiên.
    final title = thread.jobTitle;
    final subtitle = '• ${thread.memberIds.length} thành viên';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        Text(subtitle, style: subtitleStyle),
      ],
    );
  }

  Future<void> _openWallpaperPicker() async {
    final changed = await showChatWallpaperPicker(
      context: context,
      groupId: widget.groupId,
      isCandidateTheme: !widget.isEmployer,
    );
    if (changed && mounted) await _loadWallpaper();
  }

  Future<void> _openGroupManagement(ConversationThread thread) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('groupChats')
          .doc(thread.groupId)
          .get();
      if (!snap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy nhóm chat')),
          );
        }
        return;
      }
      final group = GroupChatModel.fromMap(snap.data()!, snap.id);
      await Get.to(
        () => const GroupManagementScreen(),
        arguments: {'group': group, 'isCandidate': !widget.isEmployer},
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 320),
      );
      await _loadWallpaper();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không mở được quản lý nhóm: $e')),
        );
      }
    }
  }

  // ignore: unused_element
  void _showComingSoon(String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature sẽ cập nhật sớm')));
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text;
    if (text.trim().isEmpty) return;
    _textCtrl.clear();
    try {
      await _ctrl.sendText(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  // ignore: unused_element
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
                if (!widget.isEmployer && thread.isGroupChat) ...[
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
                'Phân công công việc',
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
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
