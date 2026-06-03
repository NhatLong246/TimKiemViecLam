import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AlarmAlertScreen extends StatefulWidget {
  final Map<String, dynamic> payload;

  const AlarmAlertScreen({super.key, required this.payload});

  @override
  State<AlarmAlertScreen> createState() => _AlarmAlertScreenState();
}

class _AlarmAlertScreenState extends State<AlarmAlertScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _colorAnim = ColorTween(
      begin: Colors.red.shade900,
      end: Colors.redAccent,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.payload['title']?.toString() ?? 'Thông báo Khẩn!';
    final body = widget.payload['body']?.toString() ?? 'Bạn có lịch làm việc sắp diễn ra.';

    return Scaffold(
      body: AnimatedBuilder(
        animation: _colorAnim,
        builder: (context, child) {
          return Container(
            color: _colorAnim.value,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 100),
                const SizedBox(height: 30),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade900,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 10,
                  ),
                  onPressed: () {
                    // Logic tắt báo thức có thể xử lý ở đây nếu cần gọi native channel cancel,
                    // nhưng Flutter local notifications tự cancel khi user click vào notification để mở app.
                    Get.back();
                  },
                  child: const Text(
                    'ĐÃ HIỂU & TẮT',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
