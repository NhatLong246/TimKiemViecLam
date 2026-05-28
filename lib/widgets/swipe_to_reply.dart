import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kéo tin nhắn ngang để trả lời (vuốt trái hoặc phải đều được).
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
    /// Bubble căn phải (tin của mình).
    this.alignEnd = false,
    this.iconColor,
  });

  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  final bool alignEnd;
  final Color? iconColor;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const _maxDrag = 72.0;
  static const _trigger = 48.0;

  double _drag = 0;
  bool _firedThisGesture = false;

  late final AnimationController _snapCtrl;
  Animation<double>? _snapAnim;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        final anim = _snapAnim;
        if (anim != null && mounted) {
          setState(() => _drag = anim.value);
        }
      });
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _snapAnim = Tween<double>(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutCubic),
    );
    _snapCtrl
      ..reset()
      ..forward();
  }

  void _onDragEnd() {
    if (!_firedThisGesture && _drag.abs() >= _trigger) {
      _firedThisGesture = true;
      widget.onReply();
      HapticFeedback.lightImpact();
    }
    _firedThisGesture = false;
    _animateTo(0);
  }

  Widget _replyIcon(double progress, {required bool onRight}) {
    final iconColor = widget.iconColor ?? Colors.grey.shade600;
    final icon = Icon(
      Icons.reply_rounded,
      color: iconColor.withValues(alpha: 0.45 + 0.55 * progress),
      size: 22,
    );
    return Opacity(
      opacity: progress,
      child: Transform.scale(
        scale: 0.75 + 0.25 * progress,
        child: onRight
            ? Transform.flip(flipX: true, child: icon)
            : icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final progress = (_drag.abs() / _maxDrag).clamp(0.0, 1.0);

    return SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_drag > 0)
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _replyIcon(progress, onRight: false),
              ),
            ),
          if (_drag < 0)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: _replyIcon(progress, onRight: true),
              ),
            ),
          Align(
            alignment: widget.alignEnd
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                _snapCtrl.stop();
                setState(() {
                  _drag = (_drag + details.delta.dx)
                      .clamp(-_maxDrag, _maxDrag);
                });
              },
              onHorizontalDragEnd: (_) => _onDragEnd(),
              onHorizontalDragCancel: _onDragEnd,
              child: Transform.translate(
                offset: Offset(_drag, 0),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
