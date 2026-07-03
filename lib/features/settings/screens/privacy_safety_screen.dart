import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'package:theydi/core/router/app_routes.dart';

// Stream user's privacy settings from Firestore
final _privacySettingsProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value({});
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) {
    final data = doc.data() ?? {};
    return data['privacySettings'] as Map<String, dynamic>? ??
        {
          'profileVisible': true,
          'showCity': true,
          'showEventsAttended': true,
          'allowMessages': true,
          'showInterests': true,
        };
  });
});

class PrivacySafetyScreen extends ConsumerWidget {
  const PrivacySafetyScreen({super.key});

  Future<void> _updateSetting(String key, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'privacySettings': {key: value},
    }, SetOptions(merge: true));
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final passwordController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Account?',
            style: TheyDiTextStyles.headlineMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is permanent. All your data, events, and bookings will be deleted and cannot be recovered.',
              style: TheyDiTextStyles.bodyMedium
                  .copyWith(color: TheyDiColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text('Enter your password to confirm:',
                style: TheyDiTextStyles.caption
                    .copyWith(color: TheyDiColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TheyDiTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TheyDiTextStyles.bodySmall
                    .copyWith(color: TheyDiColors.textMuted),
                filled: true,
                fillColor: TheyDiColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: TheyDiColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: TheyDiColors.divider),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete Forever',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final password = passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password is required to delete account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: TheyDiColors.primary),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = user.email!;

      // Re-authenticate (required by Firebase before deletion)
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      final uid = user.uid;

      // Delete user's notifications subcollection
      final notifDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in notifDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete user's Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

      // Delete Firebase Auth account
      await user.delete();

      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to login
        context.go('/login');
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'wrong-password'
                  ? 'Wrong password. Please try again.'
                  : 'Failed: ${e.message}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(_privacySettingsProvider);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: TheyDiColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text('Privacy & Safety',
                        style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 16),

              Expanded(
                child: settingsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: TheyDiColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Text('Failed to load: $e',
                        style: TheyDiTextStyles.bodySmall),
                  ),
                  data: (settings) {
                    return ListView(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Privacy section
                        _SectionHeader(title: 'Profile privacy')
                            .animate(delay: 100.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 8),

                        _ToggleTile(
                          icon: Icons.visibility_outlined,
                          title: 'Profile visible to others',
                          subtitle:
                              'Others can see your profile and bio',
                          value: settings['profileVisible'] ?? true,
                          onChanged: (val) =>
                              _updateSetting('profileVisible', val),
                        ).animate(delay: 150.ms).fade(duration: 300.ms),

                        _ToggleTile(
                          icon: Icons.location_on_outlined,
                          title: 'Show my city',
                          subtitle:
                              'Display your city on your profile',
                          value: settings['showCity'] ?? true,
                          onChanged: (val) =>
                              _updateSetting('showCity', val),
                        ).animate(delay: 200.ms).fade(duration: 300.ms),

                        _ToggleTile(
                          icon: Icons.event_outlined,
                          title: 'Show events attended',
                          subtitle:
                              'Others can see events you\'ve been to',
                          value:
                              settings['showEventsAttended'] ?? true,
                          onChanged: (val) => _updateSetting(
                              'showEventsAttended', val),
                        ).animate(delay: 250.ms).fade(duration: 300.ms),

                        _ToggleTile(
                          icon: Icons.interests_outlined,
                          title: 'Show my interests',
                          subtitle:
                              'Display your interests on your profile',
                          value: settings['showInterests'] ?? true,
                          onChanged: (val) =>
                              _updateSetting('showInterests', val),
                        ).animate(delay: 300.ms).fade(duration: 300.ms),

                        const SizedBox(height: 24),

                        // Communication section
                        _SectionHeader(title: 'Communication')
                            .animate(delay: 350.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 8),

                        _ToggleTile(
                          icon: Icons.chat_bubble_outline,
                          title: 'Allow messages',
                          subtitle:
                              'Let other users send you messages',
                          value: settings['allowMessages'] ?? true,
                          onChanged: (val) =>
                              _updateSetting('allowMessages', val),
                        ).animate(delay: 400.ms).fade(duration: 300.ms),

                        const SizedBox(height: 24),

                        // Safety tools section
                        _SectionHeader(title: 'Safety tools')
                            .animate(delay: 450.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 8),

                        _ActionTile(
                          icon: Icons.block_outlined,
                          title: 'Blocked users',
                          subtitle: 'Manage your blocked list',
                          // onTap: () {
                          //   ScaffoldMessenger.of(context).showSnackBar(
                          //     const SnackBar(
                          //       content: Text(
                          //           'Blocked users — coming soon'),
                          //     ),
                          //   );
                          // },
                          onTap: () {
  context.push(AppRoutes.blockedUsers);
}
                        ).animate(delay: 500.ms).fade(duration: 300.ms),

                        _ActionTile(
                          icon: Icons.flag_outlined,
                          title: 'Report a problem',
                          subtitle:
                              'Report inappropriate content or behaviour',
                          onTap: () {
  context.push(AppRoutes.reportProblem);
},
                        ).animate(delay: 550.ms).fade(duration: 300.ms),

                        const SizedBox(height: 24),

                        // Danger zone
                        _SectionHeader(
                                title: 'Danger zone',
                                color: TheyDiColors.error)
                            .animate(delay: 600.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 8),

                        _ActionTile(
                          icon: Icons.delete_forever_outlined,
                          title: 'Delete account',
                          subtitle:
                              'Permanently delete your account and data',
                          iconColor: TheyDiColors.error,
                          titleColor: TheyDiColors.error,
                          onTap: () => _deleteAccount(context),
                        ).animate(delay: 650.ms).fade(duration: 300.ms),

                        const SizedBox(height: 40),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header ──
class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;
  const _SectionHeader({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        title.toUpperCase(),
        style: TheyDiTextStyles.caption.copyWith(
          color: color ?? TheyDiColors.textMuted,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Toggle Tile ──
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: TheyDiColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TheyDiTextStyles.labelMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: TheyDiTextStyles.caption),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: TheyDiColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Action Tile ──
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: iconColor ?? TheyDiColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TheyDiTextStyles.labelMedium.copyWith(
                        color: titleColor,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TheyDiTextStyles.caption),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: TheyDiColors.textMuted),
          ],
        ),
      ),
    );
  }
}
