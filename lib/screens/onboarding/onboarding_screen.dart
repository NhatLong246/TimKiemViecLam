import 'package:flutter/material.dart';
import '../../controller/onboarding_controller.dart';
import '../../routes/app_routes.dart';
import '../../utils/preferences_helper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingController controller;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    controller = OnboardingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheImages());
  }

  Future<void> _precacheImages() async {
    if (!mounted || controller.onboardingPages.isEmpty) return;
    await precacheImage(
      AssetImage(controller.onboardingPages.first.imagePath),
      context,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _goToHome() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    await PreferencesHelper.setOnboardingCompleted(true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  Future<void> _onNextPressed() async {
    if (_isNavigating) return;
    if (controller.isLastPage()) {
      await _goToHome();
      return;
    }
    if (!controller.pageController.hasClients) return;
    await controller.pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final imageHeight = size.height * 0.22;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheH = (imageHeight * dpr).round().clamp(180, 360);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                  Color(0xFF388E3C),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(top: -80, left: -80, child: _decorCircle(260)),
                Positioned(
                  bottom: -100,
                  right: -100,
                  child: _decorCircle(320),
                ),
                Positioned(
                  top: size.height * 0.35,
                  right: -40,
                  child: _decorCircle(120),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [
                      _chip('V24h'),
                      const Spacer(),
                      GestureDetector(
                        onTap: _isNavigating ? null : _goToHome,
                        behavior: HitTestBehavior.opaque,
                        child: _chip('Bỏ qua'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: controller.pageController,
                    itemCount: controller.onboardingPages.length,
                    onPageChanged: (index) {
                      setState(() => controller.onPageChanged(index));
                    },
                    itemBuilder: (context, index) {
                      final page = controller.onboardingPages[index];
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 40,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: RepaintBoundary(
                                child: Image.asset(
                                  page.imagePath,
                                  height: imageHeight,
                                  fit: BoxFit.contain,
                                  cacheHeight: cacheH,
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) => SizedBox(
                                    height: imageHeight,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 48,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              page.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 48,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              page.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    controller.onboardingPages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: controller.currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: controller.currentPage == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isNavigating ? null : _onNextPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2E7D32),
                        disabledBackgroundColor: Colors.white70,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isNavigating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF2E7D32),
                              ),
                            )
                          : Text(
                              controller.isLastPage()
                                  ? 'Bắt đầu ngay'
                                  : 'Tiếp theo',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.06),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
