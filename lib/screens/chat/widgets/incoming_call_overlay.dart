import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/push_navigation_handler.dart';

class IncomingCallOverlay extends StatelessWidget {
  final Map<String, dynamic> payload;

  const IncomingCallOverlay({super.key, required this.payload});

  static void show(Map<String, dynamic> data) {
    // Đóng các snackbar khác nếu có để ưu tiên hiển thị cuộc gọi
    Get.closeAllSnackbars();

    Get.rawSnackbar(
      messageText: IncomingCallOverlay(payload: data),
      backgroundColor: Colors.transparent,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 45),
      isDismissible: false,
      snackStyle: SnackStyle.FLOATING,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = payload['title']?.toString() ?? 'Có cuộc gọi đến';
    final body = payload['body']?.toString() ?? 'Đang gọi video...';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF303030),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
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
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade600,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF303030), // Match background to create border effect
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0084FF), // Messenger blue
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.videocam, color: Colors.white, size: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Content and Buttons
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
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Get.closeCurrentSnackbar(),
                          child: const Text(
                            'Từ chối',
                            style: TextStyle(
                              color: Color(0xFF0084FF),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        GestureDetector(
                          onTap: () {
                            Get.closeCurrentSnackbar();
                            PushNavigationHandler.handlePayload(payload);
                          },
                          child: const Text(
                            'Trả lời',
                            style: TextStyle(
                              color: Color(0xFF0084FF),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
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
    );
  }
}
