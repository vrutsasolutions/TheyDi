// ─────────────────────────────────────────────────────────────────────────────
// signup_otp_screen.dart
//
// Email OTP verification — simulated locally (no backend yet).
// OTP is shown in a snackbar so developers can test the flow.
// Wire real email delivery (Firebase Functions + SendGrid/Nodemailer) later.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/signup_progress_bar.dart';
import '../models/signup_data.dart';

class SignupOtpScreen extends StatefulWidget {
  final SignupData signupData;
  const SignupOtpScreen({super.key, required this.signupData});

  @override
  State<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends State<SignupOtpScreen> {
  // ── 6 individual digit controllers ──
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsLeft = 30;
  Timer? _timer;
  bool _isVerifying = false;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _sendOtp(); // real async send — fire and forget on init
    _startTimer();
    // Auto-focus first box
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNodes[0].requestFocus());

    // Listen to focus changes
    for (final f in _focusNodes) {
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
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Send OTP via EmailJS + Firestore ─────────────────────────────────────
  Future<void> _sendOtp() async {
    final success = await OTPService.sendOTP(
      email: widget.signupData.email,
      name: widget.signupData.name.isNotEmpty
          ? widget.signupData.name
          : widget.signupData.email,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '❌ Failed to send OTP. Please check your email and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
    await OTPService.clearOTP(widget.signupData.email);
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    await _sendOtp();
    _startTimer();
    setState(() {});
  }

  // ── Digit input handling ───────────────────────────────────────────────────
  void _onDigitChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-verify when all 6 filled
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) _verify();
    setState(() {});
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  // ── Verify via Firestore ───────────────────────────────────────────────────
  Future<void> _verify() async {
    if (_enteredOtp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter all 6 digits'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    final result = await OTPService.verifyOTP(
      email: widget.signupData.email,
      inputOtp: _enteredOtp,
    );

    if (result['valid'] == true) {
      widget.signupData.emailVerified = true;
      if (mounted) {
        context.push(AppRoutes.signupStep2, extra: widget.signupData);
      }
    } else {
      if (mounted) {
        setState(() => _isVerifying = false);
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ ${result['message'] ?? 'Incorrect OTP. Please try again.'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: TheyDiColors.textPrimary,
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: SignupProgressBar(step: 1, totalSteps: 5),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mark_email_read_outlined,
                            color: Colors.white, size: 38),
                      )
                          .animate()
                          .scale(duration: 500.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 28),

                      Text('Verify your email',
                              style: TheyDiTextStyles.displayMedium,
                              textAlign: TextAlign.center)
                          .animate(delay: 100.ms)
                          .fade(duration: 300.ms),

                      const SizedBox(height: 10),

                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TheyDiTextStyles.bodySmall.copyWith(
                              color: TheyDiColors.textSecondary, height: 1.5),
                          children: [
                            const TextSpan(text: 'We sent a 6-digit code to\n'),
                            TextSpan(
                              text: widget.signupData.email,
                              style: TheyDiTextStyles.labelMedium
                                  .copyWith(color: TheyDiColors.primary),
                            ),
                          ],
                        ),
                      ).animate(delay: 150.ms).fade(duration: 300.ms),

                      const SizedBox(height: 40),

                      // ── 6 OTP boxes ──
                      // ── 6 OTP boxes ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) {
                          return Expanded(
                            child: Container(
                              height: 56,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: TheyDiColors.inputFill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _focusNodes[i].hasFocus ||
                                          _controllers[i].text.isNotEmpty
                                      ? TheyDiColors.primary
                                      : TheyDiColors.divider,
                                  width: _focusNodes[i].hasFocus ||
                                          _controllers[i].text.isNotEmpty
                                      ? 2
                                      : 1,
                                ),
                              ),
                              child: TextField(
                                controller: _controllers[i],
                                focusNode: _focusNodes[i],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                style: TheyDiTextStyles.displayMedium
                                    .copyWith(color: TheyDiColors.primary),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  fillColor: Colors.transparent,
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (v) => _onDigitChanged(v, i),
                                onTap: () {
                                  _controllers[i].selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                        offset: _controllers[i].text.length),
                                  );
                                },
                              ),
                            ),
                          )
                              .animate(
                                  delay: Duration(milliseconds: 200 + i * 50))
                              .fade(duration: 250.ms)
                              .slideY(begin: 0.3, end: 0);
                        }),
                      ),

                      const SizedBox(height: 40),

                      // ── Verify button ──
                      SizedBox(
                        width: double.infinity,
                        child: _isVerifying
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: TheyDiColors.primary))
                            : GradientButton(
                                label: 'Verify & Continue →',
                                onPressed:
                                    _enteredOtp.length == 6 ? _verify : () {},
                              ),
                      ).animate(delay: 500.ms).fade(duration: 300.ms),

                      const SizedBox(height: 28),

                      // ── Resend + change email ──
                      Column(
                        children: [
                          if (!_canResend)
                            Text(
                              'Resend code in $_secondsLeft s',
                              style: TheyDiTextStyles.caption
                                  .copyWith(color: TheyDiColors.textMuted),
                            )
                          else
                            TextButton(
                              onPressed: _resendOtp,
                              child: Text(
                                'Resend OTP',
                                style: TheyDiTextStyles.labelMedium
                                    .copyWith(color: TheyDiColors.primary),
                              ),
                            ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: Text(
                              'Change email address',
                              style: TheyDiTextStyles.caption
                                  .copyWith(color: TheyDiColors.textSecondary),
                            ),
                          ),
                        ],
                      ).animate(delay: 550.ms).fade(duration: 300.ms),
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
}
