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

        if (isDesktop) {
          // Use the same layered approach as mobile so the full image
          // is always visible (contain) with a blurred/tinted cover
          // behind it to fill the remaining space.
          return SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Blurred cover background fills the entire area
                Image.asset(
                  page.image,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                // Semi-opaque wash so the foreground pops
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                  ),
                ),
                // Actual image, fully visible, centered
                Image.asset(
                  page.image,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ],
            ),
          );
        }

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