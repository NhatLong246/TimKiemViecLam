import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../common/styles/app_colors.dart';
import '../controller/employer_notification_controller.dart';
import '../controller/login_controller.dart';
import '../controller/messaging_controller.dart';
import '../data/models/messaging_models.dart';
import '../routes/app_routes.dart';
import '../screens/messaging/chat_room_screen.dart';
import '../screens/messaging/conversation_list_screen.dart';
import '../utils/floating_message_bubble_preferences.dart';
import '../utils/messaging_bootstrap.dart';
import 'floating_overlay_layout.dart';

/// Bong bóng chat nổi — kéo xuống đáy để ẩn; chỉ hiện lại khi có tin chưa đọc mới.
/// Luôn có icon khi chưa ẩn; preview + số đỏ khi có tin chưa đọc.
class FloatingMessageBubble extends StatefulWidget {
  const FloatingMessageBubble({super.key, this.isEmployer = false});

  final bool isEmployer;

  @override
  State<FloatingMessageBubble> createState() => _FloatingMessageBubbleState();
}

class _FloatingMessageBubbleState extends State<FloatingMessageBubble>
    with SingleTickerProviderStateMixin {
  Color get _primary => widget.isEmployer
      ? AppColors.employerPrimary
      : AppColors.candidatePrimary;
  static const double _headSize = FloatingOverlayLayout.messageHeadSize;
  static const double _previewMaxWidth =
      FloatingOverlayLayout.messagePreviewMaxWidth;
  static const double _dragFootprint =
      FloatingOverlayLayout.messageHeadSize + 2;

  double _x = 0;
  double _y = 0;
  bool _initialized = false;
  bool _isDragging = false;
  bool _isHidden = false;
  bool _userMoved = false;
  int _hiddenWhileUnread = 0;
  Set<String> _hiddenNotifGroups = {};
  DateTime? _hiddenLastMessageAt;
  bool _hiddenSnapshotPending = false;
  bool _prefsLoaded = false;
  bool _lastShowAlert = false;

  late final AnimationController _popCtrl;
  late final Animation<double> _popAnim;

  String? _boundUserId;

  @override
  void initState() {
    super.initState();
    MessagingBootstrap.startIfLoggedIn();
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _popAnim = CurvedAnimation(parent: _popCtrl, curve: Curves.easeOutBack);
    _popCtrl.forward();
    _reloadPrefsForCurrentUser();
  }

  void _reloadPrefsForCurrentUser() {
    final uid = Get.find<AuthController>().currentUser?.id ?? '';
    if (uid.isEmpty) {
      setState(() {
        _prefsLoaded = true;
        _isHidden = false;
        _hiddenSnapshotPending = false;
      });
      return;
    }
    if (uid == _boundUserId && _prefsLoaded) return;
    _boundUserId = uid;
    unawaited(_loadDismissState(uid));
  }

  Future<void> _loadDismissState(String uid) async {
    final state = await FloatingMessageBubblePreferences.loadMessageBubble(
      uid,
      widget.isEmployer,
    );
    if (!mounted) return;
    setState(() {
      _isHidden = state.hidden;
      _hiddenWhileUnread = state.hiddenWhileUnread;
      // Không chặn hiện lại vì snapshot — sẽ chụp ngay frame đầu nếu cần.
      _hiddenSnapshotPending = false;
      _prefsLoaded = true;
    });
    if (state.hidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isHidden) return;
        if (!Get.isRegistered<MessagingController>()) return;
        setState(
          () => _captureHiddenSnapshot(Get.find<MessagingController>()),
        );
      });
    }
  }

  void _captureHiddenSnapshot(MessagingController mc) {
    _hiddenWhileUnread = mc.bubbleUnreadCount;
    _hiddenNotifGroups = Set<String>.from(mc.unreadMessageGroupIds);
    _hiddenLastMessageAt = mc.primaryUnreadThread?.lastMessageAt;
    _hiddenSnapshotPending = false;
  }

  void _markDismissed(MessagingController mc) {
    _isHidden = true;
    _hiddenSnapshotPending = true;
    final uid = Get.find<AuthController>().currentUser?.id ?? '';
    unawaited(
      FloatingMessageBubblePreferences.saveMessageBubbleDismissed(
        uid,
        widget.isEmployer,
        unreadAtDismiss: mc.bubbleUnreadCount,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isHidden) return;
      setState(() => _captureHiddenSnapshot(mc));
    });
  }

  bool _hasNewMessageSinceDismiss(MessagingController mc) {
    if (_hiddenSnapshotPending) return false;
    final groups = mc.unreadMessageGroupIds;
    for (final g in groups) {
      if (!_hiddenNotifGroups.contains(g)) return true;
    }
    final at = mc.primaryUnreadThread?.lastMessageAt;
    if (at != null) {
      if (_hiddenLastMessageAt == null) return true;
      if (at.isAfter(_hiddenLastMessageAt!)) return true;
    }
    return mc.bubbleUnreadCount > _hiddenWhileUnread;
  }

  Future<void> _restoreFromNewMessage(int total) async {
    final uid = Get.find<AuthController>().currentUser?.id ?? '';
    await FloatingMessageBubblePreferences.clearMessageBubbleDismissed(
      uid,
      widget.isEmployer,
    );
    if (!mounted) return;
    final sz = MediaQuery.sizeOf(context);
    setState(() {
      _isHidden = false;
      _hiddenWhileUnread = 0;
      _hiddenNotifGroups = {};
      _hiddenLastMessageAt = null;
      _hiddenSnapshotPending = false;
      _userMoved = false;
      _initPosition(sz, showAlert: total > 0);
    });
    _popCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    super.dispose();
  }

  void _initPosition(Size size, {required bool showAlert}) {
    _x = FloatingOverlayLayout.messageLeft(size, hasPreview: showAlert);
    _y = FloatingOverlayLayout.messageTop(size);
    _lastShowAlert = showAlert;
  }

  double _bubbleWidth(bool showAlert) =>
      showAlert ? _headSize + 8 + _previewMaxWidth : _headSize;

  void _syncXForAlertChange(Size size, bool showAlert) {
    if (showAlert == _lastShowAlert) return;
    _x = FloatingOverlayLayout.messageLeft(size, hasPreview: showAlert);
    _lastShowAlert = showAlert;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final size = MediaQuery.sizeOf(context);
      final hasUnread = Get.isRegistered<MessagingController>() &&
          Get.find<MessagingController>().unreadTotal.value > 0;
      _initPosition(size, showAlert: hasUnread);
      _initialized = true;
    }
  }

  Future<void> _openChat(ConversationThread? thread, int totalUnread) async {
    final mc = MessagingBootstrap.ensureController();
    if (!mounted) return;

    if (widget.isEmployer) {
      if (totalUnread == 1 && thread != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              groupId: thread.groupId,
              isEmployer: true,
            ),
          ),
        );
        if (mounted) await mc.markConversationRead(thread.groupId);
        return;
      }
      await Get.toNamed(AppRoutes.employerMessages);
      return;
    }

    if (totalUnread == 1 && thread != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            groupId: thread.groupId,
            isEmployer: false,
          ),
        ),
      );
      if (mounted) await mc.markConversationRead(thread.groupId);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConversationListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AuthController>(
      builder: (auth) {
        if (auth.currentUser == null) return const SizedBox.shrink();
        _reloadPrefsForCurrentUser();
        if (!_prefsLoaded) return const SizedBox.shrink();

        MessagingBootstrap.ensureController().ensureInboxListening();

        return Obx(() {
          final messaging = Get.find<MessagingController>();
          // ignore: unused_local_variable — kích Obx khi thông báo tin đổi
          final _ = messaging.unreadNotifTick.value;
          final inboxUnread = messaging.unreadTotal.value;
          if (widget.isEmployer &&
              Get.isRegistered<EmployerNotificationController>()) {
            // ignore: unused_local_variable
            final employerBadgeTick = Get.find<EmployerNotificationController>()
                .unreadBadgeCount
                .value;
          }
          final total = messaging.bubbleUnreadCount;
          final thread = messaging.primaryUnreadThread;

          // Hết tin chưa đọc → luôn hiện lại icon (không giữ trạng thái ẩn cũ).
          if (_isHidden && total == 0 && inboxUnread == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_isHidden) return;
              unawaited(_restoreFromNewMessage(0));
            });
          }

          if (_isHidden) {
            if (_hasNewMessageSinceDismiss(messaging)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_isHidden) return;
                final mc = Get.find<MessagingController>();
                if (_hasNewMessageSinceDismiss(mc)) {
                  unawaited(_restoreFromNewMessage(mc.bubbleUnreadCount));
                }
              });
            }
            return const SizedBox.shrink();
          }

          return _buildBubbleBody(context, total, thread);
        });
      },
    );
  }

  Widget _buildBubbleBody(
    BuildContext context,
    int total,
    ConversationThread? thread,
  ) {
    final showAlert = total > 0;
    if (showAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_popCtrl.isCompleted) {
          _popCtrl.forward(from: 0.85);
        }
      });
    }

    final size = MediaQuery.sizeOf(context);

    if (!_userMoved) {
      if (!_initialized) {
        _initPosition(size, showAlert: showAlert);
        _initialized = true;
      }
      final targetY = FloatingOverlayLayout.messageTop(size);
      if ((_y - targetY).abs() > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _userMoved) return;
          setState(() {
            _y = targetY;
            _lastShowAlert = showAlert;
          });
        });
      }
    } else if (showAlert != _lastShowAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          if (_userMoved) {
            _syncXForAlertChange(size, showAlert);
          } else {
            _lastShowAlert = showAlert;
          }
        });
      });
    }

    final title = thread == null
        ? 'Tin nhắn mới'
        : (thread.isGroupChat ? thread.jobTitle : thread.peerName);
    final preview = thread?.lastMessageText ?? 'Bạn có tin nhắn mới';
    final letter = showAlert && thread != null
        ? thread.listAvatarLetter(groupTab: thread.isGroupChat)
        : null;
    final badge = showAlert ? (total > 99 ? '99+' : '$total') : null;

    return Positioned.fill(
      child: Stack(
        children: [
          if (_isDragging) _buildCloseTarget(size),
          Positioned(
            left: _userMoved ? _x : null,
            right: _userMoved ? null : FloatingOverlayLayout.rightMargin,
            top: _userMoved
                ? _y
                : FloatingOverlayLayout.messageTop(size),
            child: GestureDetector(
              onPanStart: (_) {
                setState(() {
                  _isDragging = true;
                  if (!_userMoved) {
                    _userMoved = true;
                    _x = FloatingOverlayLayout.messageLeft(
                      size,
                      hasPreview: showAlert,
                    );
                  }
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  final w = _bubbleWidth(showAlert);
                  _x = (_x + details.delta.dx).clamp(0, size.width - w);
                  _y = (_y + details.delta.dy).clamp(
                    0,
                    size.height - _dragFootprint,
                  );
                });
              },
              onPanEnd: (_) {
                final shouldHide = _y > size.height - 140;
                setState(() {
                  _isDragging = false;
                  if (shouldHide) {
                    _markDismissed(Get.find<MessagingController>());
                  }
                });
              },
              onPanCancel: () => setState(() => _isDragging = false),
              onTap: () async => _openChat(thread, total),
              child: ScaleTransition(
                scale: _popAnim,
                child: Material(
                  color: Colors.transparent,
                  elevation: showAlert ? 8 : 4,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(28),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    textDirection: TextDirection.rtl,
                    children: [
                      _buildAvatar(letter: letter, badge: badge),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        alignment: Alignment.centerRight,
                        child: showAlert
                            ? Row(
                                children: [
                                  const SizedBox(width: 8),
                                  _buildPreviewCard(title, preview),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(String title, String preview) {
    return Container(
      constraints: const BoxConstraints(maxWidth: _previewMaxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({String? letter, String? badge}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _headSize,
          height: _headSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _primary.withValues(alpha: 0.15),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: letter != null
              ? Text(
                  letter,
                  style: TextStyle(
                    color: _primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : Icon(Icons.forum_rounded, color: _primary, size: 26),
        ),
        if (badge != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCloseTarget(Size size) {
    const bottomNav = 88.0;
    final dismissZoneTop = size.height - 140;
    final isVisible = _y > dismissZoneTop - 80;
    final isNearBottom = _y > dismissZoneTop;

    return Positioned(
      left: (size.width - 78) / 2,
      bottom: bottomNav,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: isVisible ? 1 : 0,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            scale: isVisible ? (isNearBottom ? 1.12 : 1.0) : 0.85,
            curve: Curves.easeOut,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isNearBottom
                    ? const Color(0xFFE53935)
                    : Colors.black.withValues(alpha: 0.68),
                boxShadow: [
                  BoxShadow(
                    color: isNearBottom
                        ? const Color(0xFFE53935).withValues(alpha: 0.38)
                        : Colors.black.withValues(alpha: 0.18),
                    blurRadius: isNearBottom ? 22 : 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: isNearBottom ? 34 : 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
