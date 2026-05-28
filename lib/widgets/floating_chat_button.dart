import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/login_controller.dart';
import 'package:viecnow/screens/chatbot/chatbot_screen.dart';
import '../utils/floating_message_bubble_preferences.dart';
import 'floating_overlay_layout.dart';

class FloatingChatButton extends StatefulWidget {
  const FloatingChatButton({super.key});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with TickerProviderStateMixin {
  double _x = 0;
  double _y = 0;
  bool _initialized = false;
  bool _showTooltip = true;
  bool _isDragging = false;
  bool _isHidden = false;
  bool _userMoved = false;
  bool _prefsLoaded = false;
  String? _loadedForUserId;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _tooltipCtrl;
  late final Animation<double> _tooltipAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _tooltipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    _tooltipAnim = CurvedAnimation(parent: _tooltipCtrl, curve: Curves.easeOut);

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _hideTooltip();
    });

    final uid = Get.find<AuthController>().currentUser?.id ?? '';
    if (uid.isNotEmpty) {
      _loadedForUserId = uid;
      _loadDismissState(uid);
    }
  }

  void _applyDefaultPosition(Size size) {
    if (_userMoved) return;
    _x = FloatingOverlayLayout.chatbotLeft(size);
    _y = FloatingOverlayLayout.chatbotTop(size);
    _initialized = true;
  }

  Future<void> _loadDismissState(String uid) async {
    final hidden = await FloatingMessageBubblePreferences.loadChatbotHidden(uid);
    if (!mounted || _loadedForUserId != uid) return;
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _isHidden = hidden;
      _prefsLoaded = true;
      if (!_initialized) _applyDefaultPosition(size);
    });
  }

  void _ensureDismissLoadedForUser(String uid) {
    if (uid.isEmpty) return;
    if (uid == _loadedForUserId && _prefsLoaded) return;
    _loadedForUserId = uid;
    _prefsLoaded = false;
    _loadDismissState(uid);
  }

  Future<void> _persistDismiss() async {
    final uid = Get.find<AuthController>().currentUser?.id ?? '';
    await FloatingMessageBubblePreferences.saveChatbotDismissed(uid);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && _prefsLoaded) {
      final size = MediaQuery.of(context).size;
      _x = FloatingOverlayLayout.chatbotLeft(size);
      _y = FloatingOverlayLayout.chatbotTop(size);
      _initialized = true;
    }
  }

  void _hideTooltip() {
    _tooltipCtrl.reverse().then((_) {
      if (mounted) setState(() => _showTooltip = false);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _tooltipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = Get.find<AuthController>().currentUser?.id ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();

    _ensureDismissLoadedForUser(uid);
    if (!_prefsLoaded) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    if (!_initialized && !_userMoved) {
      _applyDefaultPosition(size);
    }
    final topY = _userMoved ? _y : FloatingOverlayLayout.chatbotTop(size);
    final isRightSide = _x > size.width / 2;

    if (_isHidden) return const SizedBox.shrink();

    return Positioned.fill(
      child: Stack(
        children: [
          if (_isDragging) _buildCloseTarget(size),
          Positioned(
            left: _userMoved ? _x : null,
            right: _userMoved ? null : FloatingOverlayLayout.rightMargin,
            top: topY,
            child: GestureDetector(
              onPanStart: (_) {
                setState(() {
                  _isDragging = true;
                  if (!_userMoved) {
                    _userMoved = true;
                    _x = FloatingOverlayLayout.chatbotLeft(size);
                  }
                });
                if (_showTooltip) _hideTooltip();
              },
              onPanUpdate: (details) {
                setState(() {
                  _x = (_x + details.delta.dx).clamp(
                    0,
                    size.width - FloatingOverlayLayout.chatbotSize - 2,
                  );
                  _y = (_y + details.delta.dy).clamp(
                    0,
                    size.height - FloatingOverlayLayout.chatbotSize - 2,
                  );
                });
              },
              onPanEnd: (_) {
                final shouldHide = _y > size.height - 140;
                setState(() {
                  _isDragging = false;
                  if (shouldHide) _isHidden = true;
                });
                if (shouldHide) unawaited(_persistDismiss());
              },
              onPanCancel: () => setState(() => _isDragging = false),
              onTap: () {
                if (_showTooltip) _hideTooltip();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                );
              },
              child: Column(
                crossAxisAlignment: isRightSide
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showTooltip) _buildTooltip(),
                  if (_showTooltip) const SizedBox(height: 6),
                  _buildButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseTarget(Size size) {
    final isVisible = _y > size.height - 220;
    final isNearBottom = _y > size.height - 140;

    return Positioned(
      left: (size.width - 78) / 2,
      bottom: 76,
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

  Widget _buildTooltip() {
    return FadeTransition(
      opacity: _tooltipAnim,
      child: ScaleTransition(
        scale: _tooltipAnim,
        alignment: Alignment.bottomRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _hideTooltip,
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Color(0xFF999999),
                ),
              ),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  '✨ Cần tư vấn việc làm?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) =>
          Transform.scale(scale: _pulseAnim.value, child: child),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF43A047), Color(0xFF1565C0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(
          Icons.smart_toy_outlined,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
