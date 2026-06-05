import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/push_navigation_handler.dart';

class IncomingCallOverlay {
  IncomingCallOverlay._();

  /// Cờ cho biết đang trong cuộc gọi → không hiện overlay mới
  static bool _isInCall = false;

  /// OverlayEntry hiện tại
  static OverlayEntry? _currentOverlay;

  /// Đánh dấu đang trong cuộc gọi
  static void markInCall() {
    _isInCall = true;
    dismiss();
  }

  /// Đánh dấu đã kết thúc cuộc gọi
  static void markCallEnded() {
    _isInCall = false;
  }

  /// Đóng overlay
  static void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Hiện overlay cuộc gọi đến
  static void show(Map<String, dynamic> data) {
    if (_isInCall) return;

    // Đóng overlay cũ nếu có
    dismiss();

    final overlay = Get.key.currentState?.overlay;
    if (overlay == null) return;

    _currentOverlay = OverlayEntry(
      builder: (context) => _IncomingCallWidget(
        payload: data,
        onDecline: () {
          debugPrint('📞 [Overlay] Nhấn TỪ CHỐI');
          dismiss();
        },
        onAccept: () {
          debugPrint('📞 [Overlay] Nhấn TRẢ LỜI');
          _isInCall = true;
          dismiss();
          Future.delayed(const Duration(milliseconds: 100), () {
            PushNavigationHandler.handlePayload(data);
          });
        },
      ),
    );

    overlay.insert(_currentOverlay!);

    // Tự đóng sau 45 giây
    Future.delayed(const Duration(seconds: 45), () {
      if (_currentOverlay != null) {
        dismiss();
      }
    });
  }
}

class _IncomingCallWidget extends StatefulWidget {
  final Map<String, dynamic> payload;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  const _IncomingCallWidget({
    required this.payload,
    required this.onDecline,
    required this.onAccept,
  });

  @override
  State<_IncomingCallWidget> createState() => _IncomingCallWidgetState();
}

class _IncomingCallWidgetState extends State<_IncomingCallWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.payload['title']?.toString() ?? 'Có cuộc gọi đến';
    final body = widget.payload['body']?.toString() ?? 'Đang gọi...';
    final isVideo = widget.payload['isVideo']?.toString() == 'true' ||
        body.toLowerCase().contains('video');

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 10,
      right: 10,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF303030),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade600,
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 32),
                        ),
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF303030),
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0084FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isVideo ? Icons.videocam : Icons.phone,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Nội dung + nút
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' • ViecNow',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                isVideo ? Icons.videocam_outlined : Icons.phone_outlined,
                                color: Colors.white70,
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                body,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // === NÚT TỪ CHỐI / TRẢ LỜI ===
                          Row(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: widget.onDecline,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Text(
                                    'Từ chối',
                                    style: TextStyle(
                                      color: Color(0xFF0084FF),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: widget.onAccept,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0084FF),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Trả lời',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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
          ),
        ),
      ),
    );
  }
}
