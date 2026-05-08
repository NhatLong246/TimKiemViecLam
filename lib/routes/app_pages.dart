import 'package:get/get.dart';
import '../screens/spalsh/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../bindings/splash_binding.dart';
import '../bindings/onboarding_binding.dart';
import 'app_routes.dart';

class AppPages {
  static final List<GetPage> pages = <GetPage>[
    GetPage(
      name: AppRoutes.splash,
      page: () => SplashScreen(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => OnboardingScreen(),
      binding: OnboardingBinding(),
    ),
  ];
}
