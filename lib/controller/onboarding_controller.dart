import 'package:flutter/material.dart';
import '../data/models/onboarding_model.dart';

class OnboardingController extends ChangeNotifier {
  int currentPage = 0;
  final PageController pageController = PageController();
  final List<OnboardingModel> onboardingPages = [
    OnboardingModel(
      title: 'Chọn đúng vật liệu',
      description: 'Xi măng, sắt thép, gạch đá và thiết bị hoàn thiện trong một ứng dụng.',
      imagePath: 'assets/images/on_boarding_images/sammy-line-delivery.gif',
    ),
    OnboardingModel(
      title: 'Giá rõ ràng và ưu đãi',
      description: 'So sánh giá nhanh, theo dõi khuyến mãi và đặt hàng theo ngân sách công trình.',
      imagePath: 'assets/images/on_boarding_images/sammy-line-searching.gif',
    ),
    OnboardingModel(
      title: 'Giao hàng tận nơi',
      description: 'Đặt hàng hôm nay, giao nhanh đến công trình hoặc cửa hàng của bạn.',
      imagePath: 'assets/images/on_boarding_images/sammy-line-shopping.gif',
    ),
  ];

  void onPageChanged(int index) {
    currentPage = index;
    notifyListeners();
  }

  bool isLastPage() {
    return currentPage == onboardingPages.length - 1;
  }
}
