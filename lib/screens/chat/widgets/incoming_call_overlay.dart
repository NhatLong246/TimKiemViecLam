import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/push_navigation_handler.dart';

/// Hiển thị dạng popup ở giữa màn hình khi có cuộc gọi đến và app đang mở
class IncomingCallOverlay extends StatelessWidget {
  final Map<String, dynamic> payload;

  const IncomingCallOverlay({super.key, required this.payload});

  static void show(Map<String, dynamic> data) {
    if (Get.isDialogOpen == true) return;
    Get.dialog(
      IncomingCallOverlay(payload: data),
      barrierDismissible: false,
      useSafeArea: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = payload['title']?.toString() ?? 'Có cuộc gọi đến';
    final body = payload['body']?.toString() ?? 'Cuộc gọi thoại';
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF1E1E1E), // Màu tối giống Messenger
      elevation: 20,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade700,
              ),
              child: const Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            // Tên người/nhóm gọi
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Loại cuộc gọi (Video/Thoại)
            Text(
              body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Nút bấm
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Nút Từ chối
                GestureDetector(
                  onTap: () {
                    Get.back(); // Tắt popup
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 8),
                      const Text('Từ chối', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                
                const SizedBox(width: 24),
                
                // Nút Trả lời
                GestureDetector(
                  onTap: () {
                    Get.back(); // Tắt popup
                    PushNavigationHandler.handlePayload(payload);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 8),
                      const Text('Trả lời', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
