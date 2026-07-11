import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

import '../../../core/theme/app_theme.dart';

enum _VerifyStep { idle, scanning, submitted }

class VerifyProfileScreen extends StatefulWidget {
  const VerifyProfileScreen({super.key});

  @override
  State<VerifyProfileScreen> createState() => _VerifyProfileScreenState();
}

class _VerifyProfileScreenState extends State<VerifyProfileScreen>
    with SingleTickerProviderStateMixin {
  _VerifyStep _step = _VerifyStep.idle;
  late final AnimationController _pulseController;
  bool _isSaving = false;
  String? _saveError;

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

  Future<void> _startVerification() async {
  await context.push(AppRoutes.faceVerification);

  if (!mounted) return;

  setState(() {
    _step = _VerifyStep.submitted;
  });
}

  Future<void> _completeVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isVerified': true,
        'verificationStatus': 'verified',
        'trustScore': 80,
      });
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveError = 'Unable to save verification. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: TheyDiColors.textPrimary,
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Verify Profile',
                        style: TheyDiTextStyles.displaySmall.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Build trust by verifying your identity',
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textSecondary),
                  textAlign: TextAlign.center,
                ).animate(delay: 80.ms).fade(duration: 300.ms),
                const SizedBox(height: 10),
                Text(
                  'Your verified profile helps other members feel safe and makes your events easier to join.',
                  style: TheyDiTextStyles.caption
                      .copyWith(color: TheyDiColors.textMuted, height: 1.45),
                  textAlign: TextAlign.center,
                ).animate(delay: 100.ms).fade(duration: 300.ms),
                const SizedBox(height: 32),
                _buildFaceIllustration(),
                const SizedBox(height: 32),
                if (_step == _VerifyStep.idle) _buildIdleContent(),
                if (_step == _VerifyStep.scanning) _buildScanningContent(),
                if (_step == _VerifyStep.submitted) _buildSubmittedContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
          curve: Curves.elasticOut,
        );
  }

  Widget _buildIdleContent() {
    return Column(
      children: [
        _BenefitRow(
          icon: Icons.shield_outlined,
          color: TheyDiColors.warning,
          text: 'Get a verified badge on your profile',
        ),
        const SizedBox(height: 12),
        _BenefitRow(
          icon: Icons.trending_up,
          color: TheyDiColors.warning,
          text: 'Boost trust for your events and communities',
        ),
        const SizedBox(height: 12),
        _BenefitRow(
          icon: Icons.people_outline,
          color: TheyDiColors.warning,
          text: 'Show others you are a real person',
        ),
        const SizedBox(height: 32),
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
                style: TheyDiTextStyles.labelLarge
                    .copyWith(color: Colors.white)),
          ),
        ).animate(delay: 300.ms).fade(duration: 300.ms),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: TheyDiColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TheyDiColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: TheyDiColors.warning, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Face verification is simulated for now. Tap Start to continue.',
                  style: TheyDiTextStyles.caption
                      .copyWith(color: TheyDiColors.warning, height: 1.4),
                ),
              ),
            ],
          ),
        ).animate(delay: 350.ms).fade(duration: 300.ms),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => context.pop(),
          child: Text(
            'Skip for now — verify later',
            style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textMuted),
          ),
        ).animate(delay: 400.ms).fade(duration: 300.ms),
      ],
    );
  }

  Widget _buildScanningContent() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text('Scanning your face...', style: TheyDiTextStyles.headlineMedium)
            .animate()
            .fade(duration: 300.ms),
        const SizedBox(height: 12),
        Text(
          'Keep your face centered and well-lit',
          style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textSecondary),
        ).animate(delay: 100.ms).fade(duration: 300.ms),
        const SizedBox(height: 32),
        LinearProgressIndicator(
          color: TheyDiColors.warning,
          backgroundColor: TheyDiColors.warning.withValues(alpha: 0.12),
          minHeight: 3,
        ),
      ],
    );
  }

  Widget _buildSubmittedContent() {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: TheyDiColors.warning, size: 40)
            .animate()
            .scale(duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: 16),
        Text(
          'Verification submitted!',
          style: TheyDiTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ).animate(delay: 100.ms).fade(duration: 300.ms),
        const SizedBox(height: 8),
        Text(
          'Your profile will be marked verified after the review. This usually takes a few minutes.',
          style: TheyDiTextStyles.bodySmall
              .copyWith(color: TheyDiColors.textSecondary, height: 1.5),
          textAlign: TextAlign.center,
        ).animate(delay: 150.ms).fade(duration: 300.ms),
        if (_saveError != null) ...[
          const SizedBox(height: 12),
          Text(_saveError!,
              style: TheyDiTextStyles.caption.copyWith(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _completeVerification,
            style: ElevatedButton.styleFrom(
              backgroundColor: TheyDiColors.warning,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text('Continue',
                    style: TheyDiTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                    )),
          ),
        ).animate(delay: 250.ms).fade(duration: 300.ms),
      ],
    );
  }
}

class _ScanBracket extends StatelessWidget {
  final double? top, left, right, bottom;
  final double rotate;
  const _ScanBracket({this.top, this.left, this.right, this.bottom, required this.rotate});

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

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _BenefitRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
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
            child: Text(text, style: TheyDiTextStyles.bodySmall.copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }
}
