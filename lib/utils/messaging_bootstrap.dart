import 'package:get/get.dart';
import '../controller/login_controller.dart';
import '../controller/messaging_controller.dart';

/// Khởi động lắng nghe hội thoại + badge tin chưa đọc (chuông, danh sách chat).
class MessagingBootstrap {
  /// Luôn trả về controller hợp lệ (tránh Get.find lỗi → mất toàn bộ màn Tin nhắn).
  static MessagingController ensureController() {
    if (Get.isRegistered<MessagingController>()) {
      return Get.find<MessagingController>();
    }
    return Get.put(MessagingController(), permanent: true);
  }

  static void startIfLoggedIn() {
    final user = Get.find<AuthController>().currentUser;
    if (user == null || user.id.isEmpty) return;

    ensureController().ensureInboxListening();
  }

  static void stop() {
    if (Get.isRegistered<MessagingController>()) {
      Get.delete<MessagingController>(force: true);
    }
  }
}
