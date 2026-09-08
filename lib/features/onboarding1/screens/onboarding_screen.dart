import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_routes.dart';
import '../models/onboarding_model.dart';
import '../widgets/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  final List<OnboardingModel> _pages = const [
    OnboardingModel(
      image: 'assets/onboarding/onboarding_1.png',
      desktopImage: 'assets/onboarding/onboarding_1_desktop.png',
      title: 'Discover Gatherings Near You',
      description:
          'Find interesting events, activities, and gatherings happening around you.',
    ),
    OnboardingModel(
      image: 'assets/onboarding/onboarding_2.png',
      desktopImage: 'assets/onboarding/onboarding_2_desktop.png',
      title: 'Meet People. Build Your Circle.',
      description:
          'Connect with people who share your interests and turn gatherings into meaningful connections.',
    ),
    OnboardingModel(
      image: 'assets/onboarding/onboarding_3.png',
      desktopImage: 'assets/onboarding/onboarding_3_desktop.png',
      title: 'Gather. Chat. Connect.',
      description:
          'Join gatherings, communicate with ease, and stay connected before and after every event.',
    ),
    OnboardingModel(
      image: 'assets/onboarding/onboarding_4.png',
      desktopImage: 'assets/onboarding/onboarding_4_desktop.png',
      title: 'More Connections. Lower Platform Fee.',
      description:
          'Discover nearby gatherings, enjoy lower platform fees, and connect with your community.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;

    context.go(AppRoutes.login);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth > 600 && constraints.maxHeight > 600;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  clipBehavior: Clip.hardEdge,
                  onPageChanged: (int index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (
                    BuildContext context,
                    int index,
                  ) {
                    return Stack(
                      children: [
                        OnboardingPage(
                          page: _pages[index],
                        ),
                        SafeArea(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: isDesktop ? 24 : 16,
                                right: 18,
                              ),
                              child: TextButton(
                                onPressed: _skip,
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFE9FDF3),
                                  foregroundColor: const Color(0xFF079455),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 22 : 24,
                                    vertical: isDesktop ? 13 : 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'Skip',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (isDesktop)
                _DesktopControlsOverlay(
                  currentPage: _currentPage,
                  pageCount: _pages.length,
                  onNext: _nextPage,
                )
              else
                _MobileTapOverlay(
                  currentPage: _currentPage,
                  pageCount: _pages.length,
                  onNext: _nextPage,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopControlsOverlay extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final VoidCallback onNext;

  const _DesktopControlsOverlay({
    required this.currentPage,
    required this.pageCount,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLastPage = currentPage == pageCount - 1;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth = (constraints.maxWidth - 48).clamp(320.0, 560.0);

          return Stack(
            children: [
              // Gradient background panel so the controls don't overlap
              // the image content.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 160,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha(200),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 58,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PageDots(
                      currentPage: currentPage,
                      pageCount: pageCount,
                      activeColor: const Color(0xFF12B76A),
                      inactiveColor: Colors.white54,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: buttonWidth,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF12B76A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isLastPage ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.arrow_forward,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MobileTapOverlay extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final VoidCallback onNext;

  const _MobileTapOverlay({
    required this.currentPage,
    required this.pageCount,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLastPage = currentPage == pageCount - 1;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        // White bottom panel with rounded top corners
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 140 + bottomPadding,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 20 + bottomPadding,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Page indicator dots
                _PageDots(
                  currentPage: currentPage,
                  pageCount: pageCount,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF12B76A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLastPage ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared dot indicator used by both mobile and desktop overlays.
class _PageDots extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final Color activeColor;
  final Color inactiveColor;

  const _PageDots({
    required this.currentPage,
    required this.pageCount,
    this.activeColor = const Color(0xFF12B76A),
    this.inactiveColor = const Color(0xFFD9DDE2),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) {
          final active = index == currentPage;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}