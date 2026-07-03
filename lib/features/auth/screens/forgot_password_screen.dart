// ─────────────────────────────────────────────────────────────────────────────
// forgot_password_screen.dart
//
// Self-contained 4-step forgot password flow:
//   Step 1: Enter email → validate + check Firestore + generate OTP
//   Step 2: Verify OTP  → 6 boxes, 30s resend, max 5 attempts
//   Step 3: New password → min 8 chars, confirm match
//   Step 4: Success     → green tick, back to login
//
// OTP is simulated locally (shown in snackbar) — wire real email later.
// Password reset uses Firebase Auth sendPasswordResetEmail under the hood,
// but the UX presents the custom OTP + new-password UI as designed.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_button.dart';

// ── Step enum ─────────────────────────────────────────────────────────────────
enum _FpStep { enterEmail, success }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _FpStep _step = _FpStep.enterEmail;

  // Shared state
  String _email = '';

  // ── Step 1 ──
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sendingOtp = false;

  // ── Step 2 ──

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _maskedEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name[0]}${name[1]}***@$domain';
  }

  Future<void> _sendResetLink() async {
    if (!_emailFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _sendingOtp = true);

    try {
      final email = _emailController.text.trim();

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      setState(() {
        _email = email;
        _sendingOtp = false;
        _step = _FpStep.success;
      });

      _showSnack(
        'Password reset link sent successfully.',
        color: TheyDiColors.success,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() => _sendingOtp = false);

      _showSnack(
        e.message ?? 'Failed to send password reset email.',
        color: TheyDiColors.error,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _sendingOtp = false);

      _showSnack(
        'Something went wrong. Please try again.',
        color: TheyDiColors.error,
      );
    }
  }
  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            TheyDiColors.cardLight,
            TheyDiColors.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // ── App Bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: TheyDiColors.textPrimary,
                      ),
                      onPressed: () => context.pop(),
                    ),

                    // Progress Indicator (2 steps only)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(2, (i) {
                          final active =
                              i <= _step.index && _step != _FpStep.success;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient:
                                  active ? TheyDiColors.gradientPrimary : null,
                              color: active ? null : TheyDiColors.divider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _buildStep(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _FpStep.enterEmail:
        return _buildEnterEmail();

      case _FpStep.success:
        return _buildSuccess();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 1 UI — Enter Email
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEnterEmail() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Form(
        key: _emailFormKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.lock_reset_outlined,
                color: Colors.white, size: 32),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

          const SizedBox(height: 28),

          Text('Forgot Password', style: TheyDiTextStyles.displayMedium)
              .animate(delay: 80.ms)
              .fade(duration: 300.ms),
          const SizedBox(height: 8),
          Text(
            'Enter your email address and we\'ll send you a verification code to reset your password.',
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary, height: 1.5),
          ).animate(delay: 120.ms).fade(duration: 300.ms),

          const SizedBox(height: 40),

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TheyDiTextStyles.bodyMedium,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(v.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
          ).animate(delay: 180.ms).fade(duration: 300.ms),

          const SizedBox(height: 36),

          SizedBox(
                  width: double.infinity,
                  child: _sendingOtp
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: TheyDiColors.primary,
                          ),
                        )
                      : GradientButton(
                          label: 'Send Reset Link',
                          onPressed: _sendResetLink,
                        ))
              .animate(delay: 240.ms)
              .fade(duration: 300.ms),

          const SizedBox(height: 24),

          Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: Text('Back to Sign In',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: TheyDiColors.textSecondary)),
            ),
          ).animate(delay: 280.ms).fade(duration: 300.ms),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 2 UI — Verify OTP
  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  // Step 3 UI — Reset Password
  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  // Step 4 UI — Success
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Success circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: Colors.green,
              size: 54,
            ),
          ).animate().scale(
                duration: 500.ms,
                curve: Curves.elasticOut,
              ),

          const SizedBox(height: 32),

          Text(
            'Check Your Email',
            style: TheyDiTextStyles.displayMedium,
            textAlign: TextAlign.center,
          ).animate(delay: 100.ms).fade(duration: 300.ms),

          const SizedBox(height: 12),

          Text(
            'A password reset link has been sent to\n'
            '${_maskedEmail(_email)}.\n\n'
            'Open the email and follow the instructions to create a new password.',
            style: TheyDiTextStyles.bodySmall.copyWith(
              color: TheyDiColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 160.ms).fade(duration: 300.ms),

          const SizedBox(height: 48),

          ...[
            '📧 Reset link sent successfully',
            '🔒 Secure Firebase password reset',
            '✅ Login with your new password after reset',
          ].asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      e.value,
                      style: TheyDiTextStyles.bodySmall.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ),
                )
                    .animate(
                      delay: Duration(milliseconds: 240 + e.key * 80),
                    )
                    .fade(duration: 300.ms)
                    .slideY(begin: 0.1, end: 0),
              ),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: 'Back to Sign In',
              onPressed: () => context.go(AppRoutes.login),
            ),
          ).animate(delay: 520.ms).fade(duration: 300.ms),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password strength hint widget
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordStrengthHint extends StatelessWidget {
  final String password;
  const _PasswordStrengthHint({required this.password});

  _Strength get _strength {
    if (password.length < 6) return _Strength.weak;
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$&*~_\-]').hasMatch(password)) score++;
    if (score <= 1) return _Strength.weak;
    if (score == 2) return _Strength.fair;
    if (score == 3) return _Strength.good;
    return _Strength.strong;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final s = _strength;
    final Color color;
    final String label;
    final int filled;
    switch (s) {
      case _Strength.weak:
        color = Colors.red;
        label = 'Weak';
        filled = 1;
        break;
      case _Strength.fair:
        color = Colors.orange;
        label = 'Fair';
        filled = 2;
        break;
      case _Strength.good:
        color = Colors.amber;
        label = 'Good';
        filled = 3;
        break;
      case _Strength.strong:
        color = Colors.green;
        label = 'Strong';
        filled = 4;
        break;
    }

    return Row(children: [
      ...List.generate(
          4,
          (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i < filled ? color : TheyDiColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
      const SizedBox(width: 8),
      Text(label,
          style: TheyDiTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}

enum _Strength { weak, fair, good, strong }
