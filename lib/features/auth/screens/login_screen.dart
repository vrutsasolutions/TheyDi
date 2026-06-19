import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:theydi/core/router/app_routes.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _keepMeSignedIn = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: TheyDiColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':    return 'No account found with this email.';
      case 'wrong-password':    return 'Incorrect password. Please try again.';
      case 'invalid-email':     return 'Please enter a valid email address.';
      case 'user-disabled':     return 'This account has been disabled.';
      case 'too-many-requests': return 'Too many attempts. Please try again later.';
      default:                  return 'Sign in failed. Please try again.';
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            keepMeSignedIn: _keepMeSignedIn,
          );
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      final code = e.toString().contains('firebase_auth')
          ? e.toString().split(']')[1].trim()
          : 'unknown';
      _showError(_getErrorMessage(code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('T', style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text('Welcome back', style: TheyDiTextStyles.displayMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to discover gatherings near you',
                        style: TheyDiTextStyles.bodyMedium
                            .copyWith(color: TheyDiColors.textSecondary),
                      ),
                    ],
                  ).animate().fade(duration: 400.ms),

                  const SizedBox(height: 48),

                  // ── Email ──
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TheyDiTextStyles.bodyMedium,
                    decoration: const InputDecoration(
                      labelText: 'Email',
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
                  ).animate(delay: 150.ms).fade(duration: 400.ms),

                  const SizedBox(height: 16),

                  // ── Password ──
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TheyDiTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: '••••••••',
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
                  ).animate(delay: 200.ms).fade(duration: 400.ms),

                  const SizedBox(height: 12),

                  // ── Keep me signed in ──
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24, 
                        child: Checkbox(
                          value: _keepMeSignedIn,
                          activeColor: TheyDiColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (v) =>
                              setState(() => _keepMeSignedIn = v ?? true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _keepMeSignedIn = !_keepMeSignedIn),
                        child: Text(
                          'Keep me signed in',
                          style: TheyDiTextStyles.bodySmall.copyWith(
                            color: TheyDiColors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // ── Forgot password link ── (WIRED)
                      TextButton(
                        onPressed: () =>
                            context.push(AppRoutes.forgotPassword), // ← WIRED
                        child: Text(
                          'Forgot password?',
                          style: TheyDiTextStyles.labelMedium
                              .copyWith(color: TheyDiColors.primary),
                        ),
                      ),
                    ],
                  ).animate(delay: 250.ms).fade(duration: 300.ms),

                  const SizedBox(height: 16),

                  GradientButton(
                    label: _isLoading ? 'Signing in...' : 'Sign In',
                    onPressed: _isLoading ? () {} : _signIn,
                  ).animate(delay: 300.ms).fade(duration: 300.ms),

                  const SizedBox(height: 24),

                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or continue with',
                          style: TheyDiTextStyles.caption),
                    ),
                    const Expanded(child: Divider()),
                  ]).animate(delay: 350.ms).fade(duration: 300.ms),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () {},
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('G', style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: TheyDiColors.primary,
                          )),
                          const SizedBox(width: 12),
                          Text('Continue with Google',
                              style: TheyDiTextStyles.labelLarge),
                        ],
                      ),
                    ),
                  ).animate(delay: 400.ms).fade(duration: 300.ms),

                  const SizedBox(height: 48),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ",
                          style: TheyDiTextStyles.bodySmall),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.signupStep1),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Join TheyDi',
                            style: TheyDiTextStyles.labelMedium
                                .copyWith(color: TheyDiColors.primary)),
                      ),
                    ],
                  ).animate(delay: 450.ms).fade(duration: 300.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
