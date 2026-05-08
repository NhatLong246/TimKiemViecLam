import 'package:get/get.dart';
import '../routes/app_routes.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    _startTimer();
  }

  void _startTimer() async {
    await Future.delayed(Duration(seconds: 2));
    Get.offAllNamed(AppRoutes.onboarding);
  }
}
