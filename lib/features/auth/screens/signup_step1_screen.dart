import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/signup_progress_bar.dart';
import '../models/signup_data.dart';

class SignupStep1Screen extends ConsumerStatefulWidget {
  const SignupStep1Screen({super.key});

  @override
  ConsumerState<SignupStep1Screen> createState() => _SignupStep1ScreenState();
}

class _SignupStep1ScreenState extends ConsumerState<SignupStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

Future<void> _continue() async {
  if (!_formKey.currentState!.validate()) return;

  if (!_acceptedTerms) {
    showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text("Terms Required"),
    content: const Text(
      "Please accept the Terms & Conditions and Privacy Policy before continuing.",
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("OK"),
      ),
    ],
  ),
);

return;
    return;
  }

  FocusScope.of(context).unfocus();

  final signupData = SignupData(
    email: _emailController.text.trim(),
    password: _passwordController.text,
    name: _nameController.text.trim(),
  );

  context.push(AppRoutes.signupOtp, extra: signupData);
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
              // Top bar — now 5 steps
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
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create your account',
                                style: TheyDiTextStyles.displayMedium)
                            .animate()
                            .fade(duration: 400.ms),
                        const SizedBox(height: 8),
                        Text('Step 1 of 5 — Basic info',
                                style: TheyDiTextStyles.bodySmall)
                            .animate(delay: 100.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 36),

                        // ── Full Name ──
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          style: TheyDiTextStyles.bodyMedium,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'e.g. Arjun Sharma',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Name is required'
                                  : null,
                        ).animate(delay: 150.ms).fade(duration: 350.ms),

                        const SizedBox(height: 16),

                        // ── Email ──
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
                        ).animate(delay: 200.ms).fade(duration: 350.ms),

                        const SizedBox(height: 16),

                        // ── Password ──
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TheyDiTextStyles.bodyMedium,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: '8+ characters',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password is required';
                            if (v.length < 8) return 'Must be at least 8 characters';
                            return null;
                          },
                        ).animate(delay: 250.ms).fade(duration: 350.ms),

                        const SizedBox(height: 16),

                        // ── Confirm Password ──
                        TextFormField(
                          controller: _confirmController,
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
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ).animate(delay: 300.ms).fade(duration: 350.ms),

                        const SizedBox(height: 32),

                        CheckboxListTile(
  value: _acceptedTerms,
  controlAffinity: ListTileControlAffinity.leading,
  contentPadding: EdgeInsets.zero,
  onChanged: (value) {
    setState(() {
      _acceptedTerms = value ?? false;
    });
  },
  title: Wrap(
    children: [
      Text(
        'I agree to the ',
        style: TheyDiTextStyles.bodySmall,
      ),

      GestureDetector(
        onTap: () {
          context.push(AppRoutes.termsConditions);
        },
        child: Text(
          'Terms & Conditions',
          style: TheyDiTextStyles.bodySmall.copyWith(
            color: TheyDiColors.primary,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      Text(
        ' and ',
        style: TheyDiTextStyles.bodySmall,
      ),

      GestureDetector(
        onTap: () {
          context.push(AppRoutes.privacyPolicy);
        },
        child: Text(
          'Privacy Policy',
          style: TheyDiTextStyles.bodySmall.copyWith(
            color: TheyDiColors.primary,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  ),
),

                        GradientButton(
                          label: 'Continue →',
                          onPressed: _continue,
                        ).animate(delay: 350.ms).fade(duration: 300.ms),

                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account? ',
                                style: TheyDiTextStyles.bodySmall),
                            TextButton(
                              onPressed: () => context.go(AppRoutes.login),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text('Sign In',
                                  style: TheyDiTextStyles.labelMedium
                                      .copyWith(color: TheyDiColors.primary)),
                            ),
                          ],
                        ).animate(delay: 400.ms).fade(duration: 300.ms),
                      ],
                    ),
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
 