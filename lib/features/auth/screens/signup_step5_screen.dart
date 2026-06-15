// ─────────────────────────────────────────────────────────────────────────────
// signup_step5_screen.dart  —  Review & Complete
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/signup_progress_bar.dart';
import '../models/signup_data.dart';

class SignupStep5Screen extends StatefulWidget {
  final SignupData signupData;
  const SignupStep5Screen({super.key, required this.signupData});

  @override
  State<SignupStep5Screen> createState() => _SignupStep5ScreenState();
}

class _SignupStep5ScreenState extends State<SignupStep5Screen> {
  bool _isLoading = false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: TheyDiColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6), // longer so you can read it
      ),
    );
  }

  Future<void> _completeSignup() async {
    setState(() => _isLoading = true);

    User? createdUser; // track so we can delete on partial failure

    try {
      final sd = widget.signupData;

      // ── 1. Final username uniqueness guard ──────────────────────────────────
      debugPrint('[Signup] Step 1: Checking username uniqueness...');
      final usernameDoc = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(sd.username.toLowerCase())
          .get();

      if (usernameDoc.exists) {
        _showError(
            'Username @${sd.username} was just taken. Please go back and choose another.');
        setState(() => _isLoading = false);
        return;
      }

      // ── 2. Create Firebase Auth account ────────────────────────────────────
      debugPrint('[Signup] Step 2: Creating Firebase Auth account...');
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: sd.email.trim(),
        password: sd.password,
      );
      createdUser = credential.user!;
      debugPrint('[Signup] Auth account created: ${createdUser.uid}');

      // ── 3. Update display name ──────────────────────────────────────────────
      debugPrint('[Signup] Step 3: Setting display name...');
      final displayName =
          sd.displayName.isNotEmpty ? sd.displayName : sd.name;
      await createdUser.updateDisplayName(displayName);

      // ── 4. Write user profile to Firestore ─────────────────────────────────
      debugPrint('[Signup] Step 4: Writing to Firestore...');

      // Write separately instead of batch — easier to debug which one fails
      await FirebaseFirestore.instance
          .collection('users')
          .doc(createdUser.uid)
          .set(sd.toFirestoreMap(createdUser.uid));
      debugPrint('[Signup] users doc written successfully');

      await FirebaseFirestore.instance
          .collection('usernames')
          .doc(sd.username.toLowerCase())
          .set({'uid': createdUser.uid, 'username': sd.username.toLowerCase()});
      debugPrint('[Signup] usernames doc written successfully');

      // ── 5. Navigate home ────────────────────────────────────────────────────
      debugPrint('[Signup] Step 5: Navigating to home...');
      if (mounted) context.go(AppRoutes.home);

    } on FirebaseAuthException catch (e) {
      debugPrint('[Signup] FirebaseAuthException: ${e.code} — ${e.message}');
      switch (e.code) {
        case 'email-already-in-use':
          _showError('An account with this email already exists.');
          break;
        case 'weak-password':
          _showError('Password is too weak. Use at least 8 characters.');
          break;
        case 'invalid-email':
          _showError('The email address is not valid.');
          break;
        case 'network-request-failed':
          _showError('No internet connection. Please check your network.');
          break;
        default:
          _showError('Signup failed: ${e.message ?? e.code}');
      }
      // If auth was created but Firestore failed, clean up the auth account
      if (createdUser != null) {
        try { await createdUser.delete(); } catch (_) {}
      }
    } on FirebaseException catch (e) {
      // This catches Firestore permission errors and other Firebase errors
      debugPrint('[Signup] FirebaseException: ${e.code} — ${e.message}');
      if (e.code == 'permission-denied') {
        _showError(
            'Permission denied. Please update your Firebase security rules.');
      } else if (e.code == 'unavailable') {
        _showError('Firebase is unavailable. Check your internet connection.');
      } else {
        _showError('Database error (${e.code}): ${e.message}');
      }
      // Clean up the auth account since Firestore write failed
      if (createdUser != null) {
        try { await createdUser.delete(); } catch (_) {}
      }
    } catch (e, stack) {
      // Now we see the REAL error instead of hiding it
      debugPrint('[Signup] Unknown error: $e');
      debugPrint('[Signup] Stack: $stack');
      _showError('Error: ${e.toString()}');
      if (createdUser != null) {
        try { await createdUser.delete(); } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sd = widget.signupData;
    final displayName = sd.displayName.isNotEmpty ? sd.displayName : sd.name;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [TheyDiColors.cardLight, TheyDiColors.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
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
                      onPressed: _isLoading ? null : () => context.pop(),
                    ),
                    const Expanded(
                      child: SignupProgressBar(step: 5, totalSteps: 5),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text('Almost done!',
                              style: TheyDiTextStyles.displayMedium)
                          .animate(delay: 80.ms)
                          .fade(duration: 400.ms),
                      const SizedBox(height: 6),
                      Text('Review your profile before we go live',
                              style: TheyDiTextStyles.bodySmall)
                          .animate(delay: 150.ms)
                          .fade(duration: 300.ms),

                      const SizedBox(height: 28),

                      // ── Summary card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: TheyDiColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: TheyDiColors.divider),
                        ),
                        child: Column(children: [
                          // Avatar
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: TheyDiColors.gradientPrimary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'T',
                                style: TheyDiTextStyles.displayMedium
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(displayName,
                              style: TheyDiTextStyles.headlineMedium),
                          const SizedBox(height: 4),

                          // Username badge
                          if (sd.username.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: TheyDiColors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('@${sd.username}',
                                  style: TheyDiTextStyles.labelMedium
                                      .copyWith(color: TheyDiColors.primary)),
                            ),

                          Text(sd.email,
                              style: TheyDiTextStyles.bodySmall),

                          const SizedBox(height: 16),
                          const Divider(color: TheyDiColors.divider),
                          const SizedBox(height: 12),

                          _SummaryRow(
                              icon: Icons.location_city_outlined,
                              label: 'City',
                              value: sd.city.isNotEmpty
                                  ? sd.city
                                  : 'Not selected'),

                          const SizedBox(height: 8),
                          _SummaryRow(
                            icon: sd.isVerified
                                ? Icons.verified_user
                                : Icons.shield_outlined,
                            label: 'Verification',
                            value: sd.isVerified
                                ? 'Submitted — pending review'
                                : 'Skipped — verify later',
                            valueColor: sd.isVerified
                                ? TheyDiColors.warning
                                : TheyDiColors.textMuted,
                          ),

                          if (sd.bio.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _SummaryRow(
                                icon: Icons.info_outline,
                                label: 'Bio',
                                value: sd.bio),
                          ],
                          if (sd.interests.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Interests',
                                  style: TheyDiTextStyles.caption),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: sd.interests
                                    .map((i) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            gradient:
                                                TheyDiColors.gradientPrimary,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(i,
                                              style: TheyDiTextStyles.caption
                                                  .copyWith(
                                                      color: Colors.white)),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        ]),
                      )
                          .animate(delay: 200.ms)
                          .fade(duration: 400.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 32),

                      if (_isLoading)
                        const Center(
                            child: CircularProgressIndicator(
                                color: TheyDiColors.warning))
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _completeSignup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TheyDiColors.warning,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text('Let\'s Go',
                                style: TheyDiTextStyles.labelLarge.copyWith(
                                    color: Colors.white)),
                          ),
                        ).animate(delay: 350.ms).fade(duration: 300.ms),

                      // ── Debug info (only in debug mode) ──
                      if (kDebugMode) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.yellow.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Debug Info',
                                  style: TextStyle(
                                      color: Colors.yellow,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Email: ${widget.signupData.email}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 10)),
                              Text(
                                  'Username: ${widget.signupData.username}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 10)),
                              Text('City: ${widget.signupData.city}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 10)),
                              Text(
                                  'Route target: ${AppRoutes.home}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
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

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: TheyDiColors.textMuted),
      const SizedBox(width: 8),
      Text('$label: ',
          style: TheyDiTextStyles.caption
              .copyWith(color: TheyDiColors.textMuted)),
      Expanded(
        child: Text(value,
            style: TheyDiTextStyles.bodySmall.copyWith(
              color: valueColor ?? TheyDiColors.textPrimary,
            )),
      ),
    ]);
  }
}
