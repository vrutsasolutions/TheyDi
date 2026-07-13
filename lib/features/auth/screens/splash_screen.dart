import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Show splash for at least 2 seconds
    await Future.delayed(AppConstants.splashDuration);
    if (!mounted) return;

    // Check if user is already logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Already authenticated — go straight to home
      context.go(AppRoutes.home);
    } else {
      // Not authenticated — go to login
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [TheyDiColors.dark, TheyDiColors.surface, TheyDiColors.dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x6610B981),
                              blurRadius: 32,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'T',
                            style: TheyDiTextStyles.displayLarge.copyWith(
                              fontSize: 52,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .scale(
                            begin: const Offset(0.6, 0.6),
                            duration: 600.ms,
                            curve: Curves.elasticOut,
                          )
                          .fade(duration: 400.ms),

                      const SizedBox(height: 24),

                      // App name
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            TheyDiColors.gradientPrimary.createShader(bounds),
                        child: Text(
                          'TheyDi',
                          style: TheyDiTextStyles.displayLarge.copyWith(
                            fontSize: 48,
                            color: Colors.white,
                          ),
                        ),
                      )
                          .animate(delay: 300.ms)
                          .fade(duration: 500.ms)
                          .slideY(
                            begin: 0.3,
                            end: 0,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic,
                          ),

                      const SizedBox(height: 8),

                      Text(
                        AppConstants.appTagline,
                        style: TheyDiTextStyles.bodyMedium.copyWith(
                          color: TheyDiColors.textMuted,
                        ),
                      ).animate(delay: 500.ms).fade(duration: 500.ms),
                    ],
                  ),
                ),
              ),

              // Loading bar
              Padding(
  padding: const EdgeInsets.only(bottom: 40),
  child: Column(
  children: [
    const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: TheyDiColors.primary,
      ),
    ),

    const SizedBox(height: 24),

    Text(
      'From',
      style: TheyDiTextStyles.bodyMedium.copyWith(
        color: TheyDiColors.textMuted,
      ),
    ),

    const SizedBox(height: 4),

    Text(
      'Vrutsa Solutions',
      style: TheyDiTextStyles.headlineSmall.copyWith(
        color: TheyDiColors.primary,
        fontWeight: FontWeight.bold,
      ),
    ),
  ],
),
),
            ],
          ),
        ),
      ),
    );
  }
}