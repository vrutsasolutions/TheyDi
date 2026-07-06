// ─────────────────────────────────────────────────────────────────────────────
// forgot_password_screen.dart
//
// Self-contained 4-step forgot password flow (backed by your Cloud Functions):
//   Step 1: Enter email    → calls sendOtp()
//   Step 2: Verify OTP     → 6 boxes, 30s resend, max 5 attempts
//   Step 3: New password   → min 8 chars, confirm match, calls resetPassword()
//   Step 4: Success        → green tick, back to login
//
// Uses ForgotPasswordService (sendOtp / verifyOtp / resetPassword) which talks
// to your Firebase Cloud Functions backend.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/otp_service.dart'; // ForgotPasswordService
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/services/forgot_password_service.dart';

// ── Step enum ─────────────────────────────────────────────────────────────────
enum _FpStep { enterEmail, verifyOtp, newPassword, success }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _FpStep _step = _FpStep.enterEmail;
  final _service = ForgotPasswordService();

  // Shared state
  String _email = '';

  // ── Step 1: Enter Email ──
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sendingOtp = false;

  // ── Step 2: Verify OTP ──
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _verifyingOtp = false;
  int _resendSeconds = 30;
  Timer? _resendTimer;
  int _attemptsLeft = 5;

  // ── Step 3: New Password ──
  final _passwordFormKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _resettingPassword = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

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

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _clearOtpBoxes() {
    for (final c in _otpControllers) {
      c.clear();
    }
    _otpFocusNodes.first.requestFocus();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 1 — Send OTP
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _sendOtp({bool isResend = false}) async {
    if (!isResend && !_emailFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _sendingOtp = true);

    final email = isResend ? _email : _emailController.text.trim();

    final result = await _service.sendOtp(email);

    if (!mounted) return;
    setState(() => _sendingOtp = false);

    if (result['success'] == true) {
      setState(() {
        _email = email;
        _attemptsLeft = 5;
        _step = _FpStep.verifyOtp;
      });
      _clearOtpBoxes();
      _startResendTimer();
      _showSnack(
        isResend ? 'A new OTP has been sent.' : 'OTP sent to your email.',
        color: TheyDiColors.success,
      );
    } else {
      _showSnack(
        result['message'] ?? 'Failed to send OTP. Please try again.',
        color: TheyDiColors.error,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 2 — Verify OTP
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    final otp = _otpValue;
    if (otp.length != 6) {
      _showSnack('Please enter the full 6-digit code.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _verifyingOtp = true);

    final result = await _service.verifyOtp(email: _email, otp: otp);

    if (!mounted) return;
    setState(() => _verifyingOtp = false);

    if (result['success'] == true) {
      setState(() => _step = _FpStep.newPassword);
    } else {
      setState(() {
        if (_attemptsLeft > 0) _attemptsLeft--;
      });
      _clearOtpBoxes();
      _showSnack(
        result['message'] ?? 'Invalid OTP. Please try again.',
        color: TheyDiColors.error,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 3 — Reset Password
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _resettingPassword = true);

    final result = await _service.resetPassword(
      email: _email,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _resettingPassword = false);

    if (result['success'] == true) {
      setState(() => _step = _FpStep.success);
    } else {
      _showSnack(
        result['message'] ?? 'Failed to reset password. Please try again.',
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

                    // Progress Indicator (4 steps)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final active =
                              i <= _step.index && _step != _FpStep.success;
                          final done = _step == _FpStep.success;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: (active || done) ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: (active || done)
                                  ? TheyDiColors.gradientPrimary
                                  : null,
                              color: (active || done)
                                  ? null
                                  : TheyDiColors.divider,
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
      case _FpStep.verifyOtp:
        return _buildVerifyOtp();
      case _FpStep.newPassword:
        return _buildNewPassword();
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
            'Enter your email address and we\'ll send you a 6-digit code to reset your password.',
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
                          label: 'Send OTP',
                          onPressed: () => _sendOtp(),
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
  Widget _buildVerifyOtp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: TheyDiColors.gradientPrimary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.mark_email_unread_outlined,
              color: Colors.white, size: 32),
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

        const SizedBox(height: 28),

        Text('Verify Code', style: TheyDiTextStyles.displayMedium)
            .animate(delay: 80.ms)
            .fade(duration: 300.ms),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to\n${_maskedEmail(_email)}',
          style: TheyDiTextStyles.bodySmall
              .copyWith(color: TheyDiColors.textSecondary, height: 1.5),
        ).animate(delay: 120.ms).fade(duration: 300.ms),

        const SizedBox(height: 36),

        // 6 OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            6,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _otpBox(i),
            ),
          ),
        ).animate(delay: 180.ms).fade(duration: 300.ms),

        if (_attemptsLeft < 5) ...[
          const SizedBox(height: 12),
          Text(
            '$_attemptsLeft attempt${_attemptsLeft == 1 ? '' : 's'} left',
            style: TheyDiTextStyles.caption.copyWith(
              color: _attemptsLeft <= 2
                  ? TheyDiColors.error
                  : TheyDiColors.textSecondary,
            ),
          ),
        ],

        const SizedBox(height: 32),

        SizedBox(
                width: double.infinity,
                child: _verifyingOtp
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: TheyDiColors.primary,
                        ),
                      )
                    : GradientButton(
                        label: 'Verify Code',
                        onPressed: _verifyOtp,
                      ))
            .animate(delay: 240.ms)
            .fade(duration: 300.ms),

        const SizedBox(height: 20),

        Center(
          child: _resendSeconds > 0
              ? Text(
                  'Resend code in ${_resendSeconds}s',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: TheyDiColors.textSecondary),
                )
              : TextButton(
                  onPressed:
                      _sendingOtp ? null : () => _sendOtp(isResend: true),
                  child: Text(
                    'Resend Code',
                    style: TheyDiTextStyles.labelMedium
                        .copyWith(color: TheyDiColors.primary),
                  ),
                ),
        ).animate(delay: 280.ms).fade(duration: 300.ms),
      ]),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 44,
      height: 52,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TheyDiTextStyles.bodyMedium.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: TheyDiColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: TheyDiColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TheyDiColors.primary, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _otpFocusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }
          // Auto-submit once all 6 boxes are filled
          if (index == 5 && value.isNotEmpty && _otpValue.length == 6) {
            _verifyOtp();
          }
          setState(() {}); // refresh attempts/label if needed
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 3 UI — New Password
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNewPassword() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Form(
        key: _passwordFormKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.password_outlined,
                color: Colors.white, size: 32),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 28),
          Text('Create New Password', style: TheyDiTextStyles.displayMedium)
              .animate(delay: 80.ms)
              .fade(duration: 300.ms),
          const SizedBox(height: 8),
          Text(
            'Your new password must be different from your previous password.',
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary, height: 1.5),
          ).animate(delay: 120.ms).fade(duration: 300.ms),
          const SizedBox(height: 36),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TheyDiTextStyles.bodyMedium,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'Must be at least 8 characters';
              return null;
            },
          ).animate(delay: 160.ms).fade(duration: 300.ms),
          const SizedBox(height: 8),
          _PasswordStrengthHint(password: _passwordController.text)
              .animate(delay: 180.ms)
              .fade(duration: 300.ms),
          const SizedBox(height: 20),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: TheyDiTextStyles.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _passwordController.text)
                return 'Passwords do not match';
              return null;
            },
          ).animate(delay: 220.ms).fade(duration: 300.ms),
          const SizedBox(height: 36),
          SizedBox(
                  width: double.infinity,
                  child: _resettingPassword
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: TheyDiColors.primary,
                          ),
                        )
                      : GradientButton(
                          label: 'Reset Password',
                          onPressed: _resetPassword,
                        ))
              .animate(delay: 260.ms)
              .fade(duration: 300.ms),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 4 UI — Success
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 54,
            ),
          ).animate().scale(
                duration: 500.ms,
                curve: Curves.elasticOut,
              ),
          const SizedBox(height: 32),
          Text(
            'Password Reset!',
            style: TheyDiTextStyles.displayMedium,
            textAlign: TextAlign.center,
          ).animate(delay: 100.ms).fade(duration: 300.ms),
          const SizedBox(height: 12),
          Text(
            'Your password has been reset successfully.\n'
            'You can now sign in with your new password.',
            style: TheyDiTextStyles.bodySmall.copyWith(
              color: TheyDiColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 160.ms).fade(duration: 300.ms),
          const SizedBox(height: 48),
          ...[
            '✅ Email verified successfully',
            '🔒 Password updated securely',
            '🔑 Login with your new password',
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
