import 'package:flutter/material.dart';
import '../models/onboarding_model.dart';

class OnboardingPage extends StatelessWidget {
  final OnboardingModel page;

  const OnboardingPage({
    super.key,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 600;

        if (isDesktop && page.desktopImage != null) {
          // Desktop: show the full image without cropping.
          // A blurred cover fills any empty space behind it.
          return SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Blurred background fill for any letterbox areas
                Image.asset(
                  page.desktopImage!,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(140),
                  ),
                ),
                // Full image — no cropping
                Image.asset(
                  page.desktopImage!,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ],
            ),
          );
        }

        // Mobile: layered approach — blurred cover + white wash + contained image
        return SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                page.image,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(210),
                ),
              ),
              Image.asset(
                page.image,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ],
          ),
        );
      },
    );
  }
}