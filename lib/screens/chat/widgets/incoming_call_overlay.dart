import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/push_navigation_handler.dart';

class IncomingCallOverlay extends StatelessWidget {
  final Map<String, dynamic> payload;

  const IncomingCallOverlay({super.key, required this.payload});

  static void show(Map<String, dynamic> data) {
    // Ép hiển thị đè lên toàn bộ app
    Get.overlay(
      Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: IncomingCallOverlay(payload: data),
        ),
      ),
      useSafeArea: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = payload['title']?.toString() ?? 'Có cuộc gọi đến';
    final body = payload['body']?.toString() ?? 'Đang gọi video...';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: Color(0xFF00B2FF),
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(body, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              const Icon(Icons.videocam, color: Colors.white54),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('TỪ CHỐI', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
              Container(width: 1, height: 20, color: Colors.white12),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Get.back();
                    PushNavigationHandler.handlePayload(payload);
                  },
                  child: const Text('TRẢ LỜI', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
