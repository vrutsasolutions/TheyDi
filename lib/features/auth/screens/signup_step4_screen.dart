// ─────────────────────────────────────────────────────────────────────────────
// signup_step4_screen.dart  —  Profile Verification (NEW)
//
// Shows a "coming soon" face-verification placeholder.
// User can:
//   • Tap "Start Verification" → see placeholder + "submitted" state
//   • Tap "Skip" → continue unverified
//
// Wire real ML / liveness check later via a mobile SDK.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/signup_progress_bar.dart';
import '../models/signup_data.dart';

enum _VerifyStep { idle, scanning, submitted }

class SignupStep4Screen extends StatefulWidget {
  final SignupData? signupData;
  final bool fromProfile;
  const SignupStep4Screen(
      {super.key, this.signupData, this.fromProfile = false});

  @override
  State<SignupStep4Screen> createState() => _SignupStep4ScreenState();
}

class _SignupStep4ScreenState extends State<SignupStep4Screen>
    with SingleTickerProviderStateMixin {
  _VerifyStep _step = _VerifyStep.idle;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startVerification() async {
    setState(() => _step = _VerifyStep.scanning);
    // Simulate a 2.5s "scan"
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) setState(() => _step = _VerifyStep.submitted);
  }

  Future<void> _proceed({required bool verified}) async {
    if (widget.fromProfile) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'isVerified': verified,
          'verificationStatus': verified ? 'verified' : 'none',
          'trustScore': verified ? 80 : 50,
        }, SetOptions(merge: true));
      }
      if (mounted) {
        context.pop();
        if (verified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile verification completed.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      return;
    }

    if (widget.signupData != null) {
      widget.signupData!.isVerified = verified;
      if (mounted) {
        context.push(AppRoutes.signupStep5, extra: widget.signupData!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [TheyDiColors.cardLight, TheyDiColors.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar — skip button top-right
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: TheyDiColors.textPrimary,
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: SignupProgressBar(step: 4, totalSteps: 5),
                    ),
                    TextButton(
                      onPressed: () => _proceed(verified: false),
                      child: Text('Skip',
                          style: TheyDiTextStyles.labelMedium
                              .copyWith(color: TheyDiColors.textSecondary)),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Verify your profile',
                              style: TheyDiTextStyles.displayMedium,
                              textAlign: TextAlign.center)
                          .animate()
                          .fade(duration: 400.ms),
                      const SizedBox(height: 8),
                      Text('Build trust by verifying your identity',
                              style: TheyDiTextStyles.bodySmall
                                  .copyWith(color: TheyDiColors.textSecondary),
                              textAlign: TextAlign.center)
                          .animate(delay: 80.ms)
                          .fade(duration: 300.ms),
                      const SizedBox(height: 12),
                      Text('Step 4 of 5 — Optional',
                              style: TheyDiTextStyles.caption
                                  .copyWith(color: TheyDiColors.textMuted),
                              textAlign: TextAlign.center)
                          .animate(delay: 100.ms)
                          .fade(duration: 300.ms),

                      const SizedBox(height: 40),

                      // ── Face scan illustration ──
                      _buildFaceIllustration(),

                      const SizedBox(height: 40),

                      // ── Body content switches by state ──
                      if (_step == _VerifyStep.idle) _buildIdleContent(),
                      if (_step == _VerifyStep.scanning)
                        _buildScanningContent(),
                      if (_step == _VerifyStep.submitted)
                        _buildSubmittedContent(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Face illustration ───────────────────────────────────────────────────────
  Widget _buildFaceIllustration() {
    final Color borderColor;
    final IconData faceIcon;

    if (_step == _VerifyStep.submitted) {
      borderColor = TheyDiColors.warning;
      faceIcon = Icons.verified_user;
    } else if (_step == _VerifyStep.scanning) {
      borderColor = TheyDiColors.warning;
      faceIcon = Icons.face_retouching_natural;
    } else {
      borderColor = TheyDiColors.divider;
      faceIcon = Icons.face_outlined;
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _step == _VerifyStep.scanning
            ? 1.0 + _pulseController.value * 0.08
            : 1.0;
        return Transform.scale(
          scale: pulse,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor.withValues(alpha: 0.25),
                width: 12,
              ),
            ),
          ),
          // Middle ring
          Container(
            width: 152,
            height: 152,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
          // Face container
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              gradient: _step == _VerifyStep.submitted
                  ? LinearGradient(
                      colors: [
                        TheyDiColors.warning,
                        TheyDiColors.warning.withValues(alpha: 0.85),
                      ],
                    )
                  : TheyDiColors.gradientPrimary,
              shape: BoxShape.circle,
            ),
            child: Icon(faceIcon, color: Colors.white, size: 64),
          ),

          // Corner scan brackets
          if (_step == _VerifyStep.scanning) ...[
            _ScanBracket(top: 8, left: 8, rotate: 0),
            _ScanBracket(top: 8, right: 8, rotate: 90),
            _ScanBracket(bottom: 8, right: 8, rotate: 180),
            _ScanBracket(bottom: 8, left: 8, rotate: 270),
          ],
        ],
      ),
    ).animate(delay: 200.ms).scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1, 1),
        duration: 400.ms,
        curve: Curves.elasticOut);
  }

  // ── Idle state ──────────────────────────────────────────────────────────────
  Widget _buildIdleContent() {
    return Column(children: [
      // Trust benefits
      _BenefitRow(
        icon: Icons.shield_outlined,
        color: TheyDiColors.warning,
        text: 'Get a Verified badge on your profile',
      ),
      const SizedBox(height: 12),
      _BenefitRow(
        icon: Icons.trending_up,
        color: TheyDiColors.warning,
        text: 'Higher trust score — more event approvals',
      ),
      const SizedBox(height: 12),
      _BenefitRow(
        icon: Icons.people_outline,
        color: TheyDiColors.warning,
        text: 'Build credibility with other members',
      ),

      const SizedBox(height: 36),

      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _startVerification,
          style: ElevatedButton.styleFrom(
            backgroundColor: TheyDiColors.warning,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text('Start Verification',
              style: TheyDiTextStyles.labelLarge.copyWith(color: Colors.white)),
        ),
      ).animate(delay: 300.ms).fade(duration: 300.ms),

      const SizedBox(height: 16),

      // "Coming soon" info chip
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TheyDiColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: TheyDiColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, color: TheyDiColors.warning, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Face verification (liveness check) is available on the mobile app. '
              'Tapping Start will simulate the flow for now.',
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.warning, height: 1.4),
            ),
          ),
        ]),
      ).animate(delay: 350.ms).fade(duration: 300.ms),

      const SizedBox(height: 24),

      TextButton(
        onPressed: () => _proceed(verified: false),
        child: Text('Skip for now — verify later from Profile',
            style: TheyDiTextStyles.caption
                .copyWith(color: TheyDiColors.textMuted)),
      ).animate(delay: 400.ms).fade(duration: 300.ms),
    ]);
  }

  // ── Scanning state ──────────────────────────────────────────────────────────
  Widget _buildScanningContent() {
    return Column(children: [
      const SizedBox(height: 8),
      Text('Scanning your face...', style: TheyDiTextStyles.headlineMedium)
          .animate()
          .fade(duration: 300.ms),
      const SizedBox(height: 12),
      Text('Keep your face centred and well-lit',
              style: TheyDiTextStyles.bodySmall
                  .copyWith(color: TheyDiColors.textSecondary))
          .animate(delay: 100.ms)
          .fade(duration: 300.ms),
      const SizedBox(height: 32),
      LinearProgressIndicator(
        color: TheyDiColors.warning,
        backgroundColor: TheyDiColors.warning.withValues(alpha: 0.12),
        minHeight: 3,
      ),
    ]);
  }

  // ── Submitted state ─────────────────────────────────────────────────────────
  Widget _buildSubmittedContent() {
    return Column(children: [
      const Icon(Icons.check_circle, color: TheyDiColors.warning, size: 40)
          .animate()
          .scale(duration: 400.ms, curve: Curves.elasticOut),
      const SizedBox(height: 16),
      Text('Verification submitted!',
              style: TheyDiTextStyles.headlineMedium,
              textAlign: TextAlign.center)
          .animate(delay: 100.ms)
          .fade(duration: 300.ms),
      const SizedBox(height: 8),
      Text(
        'Your profile will be marked Verified after review.\n'
        'This usually takes a few minutes.',
        style: TheyDiTextStyles.bodySmall
            .copyWith(color: TheyDiColors.textSecondary, height: 1.5),
        textAlign: TextAlign.center,
      ).animate(delay: 150.ms).fade(duration: 300.ms),
      const SizedBox(height: 36),
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: () => _proceed(verified: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: TheyDiColors.warning,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text('Continue',
              style: TheyDiTextStyles.labelLarge.copyWith(color: Colors.white)),
        ),
      ).animate(delay: 250.ms).fade(duration: 300.ms),
    ]);
  }
}

// ── Scan bracket corner decoration ───────────────────────────────────────────
class _ScanBracket extends StatelessWidget {
  final double? top, left, right, bottom;
  final double rotate;
  const _ScanBracket(
      {this.top, this.left, this.right, this.bottom, required this.rotate});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.rotate(
        angle: rotate * 3.14159 / 180,
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white, width: 2.5),
              left: BorderSide(color: Colors.white, width: 2.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Benefit row ───────────────────────────────────────────────────────────────
class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _BenefitRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text,
              style: TheyDiTextStyles.bodySmall.copyWith(height: 1.4)),
        ),
      ]),
    );
  }
}
