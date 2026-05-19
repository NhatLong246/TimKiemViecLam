import 'package:flutter/material.dart';
import '../data/models/onboarding_model.dart';

class OnboardingController extends ChangeNotifier {
  int currentPage = 0;
  final PageController pageController = PageController();
  final List<OnboardingModel> onboardingPages = [
    OnboardingModel(
      title: 'Chào mừng đến với V24h',
      description: 'Chào mừng bạn đến với V24h – nền tảng tìm kiếm việc làm hiện đại, nơi kết nối ứng viên với hàng ngàn cơ hội nghề nghiệp hấp dẫn. Với giao diện thân thiện và dễ sử dụng, V24h giúp bạn tìm việc nhanh chóng, tiện lợi và phù hợp với kỹ năng của bản thân.',
      imagePath: 'assets/images/on_boarding_images/hello.gif',
    ),
    OnboardingModel(
      title: 'Kết nối với nhà tuyển dụng',
      description: 'V24h giúp ứng viên dễ dàng kết nối trực tiếp với các nhà tuyển dụng uy tín trên toàn quốc. Bạn có thể tìm kiếm công việc theo ngành nghề, vị trí hoặc địa điểm mong muốn, đồng thời trao đổi và ứng tuyển nhanh chóng ngay trên ứng dụng.',
      imagePath: 'assets/images/on_boarding_images/Partnership.gif',
    ),
    OnboardingModel(
      title: 'Giao lưu và làm việc hiệu quả',
      description: 'V24h không chỉ hỗ trợ tìm việc mà còn tạo môi trường làm việc và cộng tác hiệu quả. Người dùng có thể chia sẻ thông tin tuyển dụng, hỗ trợ nhau trong quá trình tìm việc và kết nối với cộng đồng để mở rộng cơ hội nghề nghiệp.',
      imagePath: 'assets/images/on_boarding_images/BlogPage.gif',
    ),
    OnboardingModel(
      title: 'Uy tín và bảo mật',
      description: 'V24h cam kết mang đến môi trường tuyển dụng minh bạch, an toàn và đáng tin cậy. Mọi thông tin cá nhân và dữ liệu người dùng đều được bảo mật chặt chẽ, giúp bạn yên tâm khi tìm kiếm và ứng tuyển công việc.',
      imagePath: 'assets/images/on_boarding_images/security.gif',
    ),
    OnboardingModel(
      title: 'Hỗ trợ tận tình',
      description: 'Đội ngũ hỗ trợ của V24h luôn sẵn sàng đồng hành cùng bạn trong suốt quá trình sử dụng ứng dụng. Chúng tôi luôn lắng nghe, giải đáp nhanh chóng và hỗ trợ người dùng để mang lại trải nghiệm tốt nhất.',
      imagePath: 'assets/images/on_boarding_images/Customersupport.gif',
    ),
  ];

  void onPageChanged(int index) {
    currentPage = index;
    notifyListeners();
  }

  bool isLastPage() {
    return currentPage == onboardingPages.length - 1;
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
