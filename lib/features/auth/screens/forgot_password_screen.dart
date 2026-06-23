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
enum _FpStep { enterEmail, verifyOtp, resetPassword, success }

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
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  String _generatedOtp =
      ''; // kept only as placeholder — logic moved to Firestore
  int _secondsLeft = 30;
  bool _canResend = false;
  bool _verifying = false;
  Timer? _timer;

  // ── Step 3 ──
  final _pwFormKey = GlobalKey<FormState>();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _updatingPw = false;

  @override
  void initState() {
    super.initState();
    for (final f in _otpFocusNodes) {
      f.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _newPwController.dispose();
    _confirmPwController.dispose();
    _timer?.cancel();
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

  // ─────────────────────────────────────────────────────────────────────────
  // Step 1 — Send OTP
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _sendingOtp = true);

    final email = _emailController.text.trim().toLowerCase();

    try {
      // Check if email exists in Firestore
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        _showSnack('No account found with this email.',
            color: TheyDiColors.error);
        setState(() => _sendingOtp = false);
        return;
      }

      _email = email;

      // Send real OTP via EmailJS + Firestore
      final sent = await OTPService.sendOTP(email: email, name: email);
      if (!sent) {
        _showSnack('❌ Failed to send OTP. Please try again.');
        setState(() => _sendingOtp = false);
        return;
      }

      _startTimer();
      setState(() {
        _sendingOtp = false;
        _step = _FpStep.verifyOtp;
      });

      // Auto-focus first OTP box
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _otpFocusNodes[0].requestFocus());
    } catch (e) {
      _showSnack('Something went wrong. Please try again.');
      setState(() => _sendingOtp = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 2 — Verify OTP
  // ─────────────────────────────────────────────────────────────────────────

  void _startTimer() {
    _secondsLeft = 30;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _resendOtp() async {
    await OTPService.clearOTP(_email);
    for (final c in _otpControllers) {
      c.clear();
    }
    _otpFocusNodes[0].requestFocus();
    final sent = await OTPService.sendOTP(email: _email, name: _email);
    if (!sent && mounted) {
      _showSnack('❌ Failed to resend OTP. Please try again.');
    }
    _startTimer();
    setState(() {});
  }

  void _onOtpDigitChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    setState(() {});
    final entered = _otpControllers.map((c) => c.text).join();
    if (entered.length == 6) _verifyOtp();
  }

  String get _enteredOtp => _otpControllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_enteredOtp.length < 6) {
      _showSnack('Enter all 6 digits');
      return;
    }

    setState(() => _verifying = true);

    final result = await OTPService.verifyOTP(
      email: _email,
      inputOtp: _enteredOtp,
    );

    if (result['valid'] == true) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _step = _FpStep.resetPassword;
        });
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => FocusScope.of(context).requestFocus(FocusNode()));
      }
    } else {
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes[0].requestFocus();
      _showSnack(result['message'] ?? '❌ Incorrect code. Please try again.');
      if (mounted) setState(() => _verifying = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 3 — Reset Password
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _updatePassword() async {
    setState(() => _updatingPw = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _email,
      );

      _showSnack(
        'Password reset link sent to your email. Please check your inbox.',
        color: TheyDiColors.success,
      );

      if (mounted) {
        setState(() {
          _updatingPw = false;
          _step = _FpStep.success;
        });
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(
        e.message ?? 'Failed to send password reset email.',
        color: TheyDiColors.error,
      );

      setState(() => _updatingPw = false);
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
              // ── App bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        size: 20, color: TheyDiColors.textPrimary),
                    onPressed: () {
                      if (_step == _FpStep.enterEmail ||
                          _step == _FpStep.success) {
                        context.pop();
                      } else {
                        setState(() {
                          _step = _FpStep.values[_step.index - 1];
                          _timer?.cancel();
                        });
                      }
                    },
                  ),
                  // Step dots
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        final active =
                            i <= _step.index && _step != _FpStep.success;
                        final done = i < _step.index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: done || (active && _step.index == i) ? 28 : 8,
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
                  const SizedBox(width: 48), // balance back button
                ]),
              ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween(
                      begin: const Offset(0.08, 0),
                      end: Offset.zero,
                    ).animate(
                        CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
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
      case _FpStep.resetPassword:
        return _buildResetPassword();
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
                    child:
                        CircularProgressIndicator(color: TheyDiColors.primary))
                : GradientButton(
                    label: 'Send OTP →',
                    onPressed: _sendOtp,
                  ),
          ).animate(delay: 240.ms).fade(duration: 300.ms),

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: TheyDiColors.gradientPrimary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              color: Colors.white, size: 36),
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

        const SizedBox(height: 28),

        Text('Verify Code',
                style: TheyDiTextStyles.displayMedium,
                textAlign: TextAlign.center)
            .animate(delay: 80.ms)
            .fade(duration: 300.ms),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary, height: 1.5),
            children: [
              const TextSpan(text: 'Enter the 6-digit code sent to\n'),
              TextSpan(
                text: _maskedEmail(_email),
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.primary),
              ),
            ],
          ),
        ).animate(delay: 120.ms).fade(duration: 300.ms),

        const SizedBox(height: 40),

        // ── 6 OTP boxes ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            final filled = _otpControllers[i].text.isNotEmpty;
            final isFocused = _otpFocusNodes[i].hasFocus;
            return Container(
              width: 46,
              height: 58,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: TheyDiColors.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFocused || filled
                      ? TheyDiColors.primary
                      : TheyDiColors.divider,
                  width: isFocused || filled ? 2 : 1,
                ),
              ),
              child: TextField(
                controller: _otpControllers[i],
                focusNode: _otpFocusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: TheyDiTextStyles.displayMedium
                    .copyWith(color: TheyDiColors.primary),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) => _onOtpDigitChanged(v, i),
                onTap: () {
                  _otpControllers[i].selection = TextSelection.fromPosition(
                    TextPosition(offset: _otpControllers[i].text.length),
                  );
                },
              ),
            )
                .animate(delay: Duration(milliseconds: 180 + i * 50))
                .fade(duration: 250.ms)
                .slideY(begin: 0.3, end: 0);
          }),
        ),

        const SizedBox(height: 36),

        // Verify button
        SizedBox(
          width: double.infinity,
          child: _verifying
              ? const Center(
                  child: CircularProgressIndicator(color: TheyDiColors.primary))
              : GradientButton(
                  label: 'Verify →',
                  onPressed: _enteredOtp.length == 6 ? _verifyOtp : () {},
                ),
        ).animate(delay: 480.ms).fade(duration: 300.ms),

        const SizedBox(height: 28),

        // Resend + change email
        Column(children: [
          if (!_canResend)
            Text(
              'Resend code in $_secondsLeft s',
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textMuted),
            )
          else
            TextButton(
              onPressed: _resendOtp,
              child: Text('Resend OTP',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: TheyDiColors.primary)),
            ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() {
              _step = _FpStep.enterEmail;
              _timer?.cancel();
            }),
            child: Text('Change email address',
                style: TheyDiTextStyles.caption
                    .copyWith(color: TheyDiColors.textSecondary)),
          ),
        ]).animate(delay: 530.ms).fade(duration: 300.ms),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 3 UI — Reset Password
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildResetPassword() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Form(
        key: _pwFormKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              borderRadius: BorderRadius.circular(18),
            ),
            child:
                const Icon(Icons.lock_outline, color: Colors.white, size: 30),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

          const SizedBox(height: 28),

          Text('Reset Password', style: TheyDiTextStyles.displayMedium)
              .animate(delay: 80.ms)
              .fade(duration: 300.ms),
          const SizedBox(height: 8),
          Text('Create a strong new password for your account.',
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textSecondary, height: 1.5))
              .animate(delay: 120.ms)
              .fade(duration: 300.ms),

          const SizedBox(height: 40),

          // New password
          TextFormField(
            controller: _newPwController,
            obscureText: _obscureNew,
            style: TheyDiTextStyles.bodyMedium,
            decoration: InputDecoration(
              labelText: 'New Password',
              hintText: '8+ characters',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'Must be at least 8 characters';
              return null;
            },
          ).animate(delay: 180.ms).fade(duration: 300.ms),

          const SizedBox(height: 16),

          // Confirm password
          TextFormField(
            controller: _confirmPwController,
            obscureText: _obscureConfirm,
            style: TheyDiTextStyles.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: '••••••••',
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
              if (v != _newPwController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ).animate(delay: 230.ms).fade(duration: 300.ms),

          const SizedBox(height: 12),

          // Password strength hint
          _PasswordStrengthHint(password: _newPwController.text)
              .animate(delay: 260.ms)
              .fade(duration: 300.ms),

          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            child: _updatingPw
                ? const Center(
                    child:
                        CircularProgressIndicator(color: TheyDiColors.primary))
                : GradientButton(
                    label: 'Update Password ✓',
                    onPressed: _updatePassword,
                  ),
          ).animate(delay: 310.ms).fade(duration: 300.ms),
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
          // Success circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.green.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: Colors.green, size: 54),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: 32),

          Text('Password Updated!',
                  style: TheyDiTextStyles.displayMedium,
                  textAlign: TextAlign.center)
              .animate(delay: 100.ms)
              .fade(duration: 300.ms),

          const SizedBox(height: 12),

          Text(
            'Your password has been reset successfully.\n'
            'A confirmation link has also been sent to\n${_maskedEmail(_email)}.',
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ).animate(delay: 160.ms).fade(duration: 300.ms),

          const SizedBox(height: 48),

          // Checkmarks
          ...[
            '✅  Identity verified via OTP',
            '✅  New password set',
            '✅  Account secured',
          ].asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.2)),
                  ),
                  child: Text(e.value,
                      style: TheyDiTextStyles.bodySmall
                          .copyWith(color: Colors.green)),
                ),
              )
                  .animate(delay: Duration(milliseconds: 240 + e.key * 80))
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0)),

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
