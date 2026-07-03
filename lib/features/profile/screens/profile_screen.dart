import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/profile_share_sheet.dart';
import '../../auth/providers/auth_provider.dart';

// ── Stream user profile doc ──
final _userProfileProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
});

// ── Live count: events CREATED by user ──
final _eventsCreatedCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('events')
      .where('creatorUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.length);
});

// ── Live count: events ATTENDED by user (excludes events they created) ──
final _eventsAttendedCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('events')
      .where('attendeeUids', arrayContains: uid)
      .snapshots()
      .map((s) =>
          s.docs.where((d) => (d.data()['creatorUid'] ?? '') != uid).length);
});

// ── Live count: friends ──
final _friendsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('friends')
      .snapshots()
      .map((s) => s.docs.length);
});

// ── Live count: friend circles ──
final _circlesCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('circles')
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.length);
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_userProfileProvider);
    final createdAsync = ref.watch(_eventsCreatedCountProvider);
    final attendedAsync = ref.watch(_eventsAttendedCountProvider);
    final friendsCountAsync = ref.watch(_friendsCountProvider);
    final circlesCountAsync = ref.watch(_circlesCountProvider);

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
          child: profileAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: TheyDiColors.primary),
            ),
            error: (e, _) => Center(
              child: Text('Error: $e', style: TheyDiTextStyles.bodySmall),
            ),
            data: (doc) {
              final data = doc.data() ?? {};
              final authUser = FirebaseAuth.instance.currentUser;

              final displayName =
                  (data['displayName'] as String?)?.isNotEmpty == true
                      ? data['displayName'] as String
                      : authUser?.displayName ?? 'TheyDi User';
              final email = (data['email'] as String?) ?? authUser?.email ?? '';
              final city = (data['city'] as String?) ?? '';
              final bio = (data['bio'] as String?) ?? '';
              final photoUrl = (data['profileImageUrl'] as String?) ??
                  (data['photoUrl'] as String?) ??
                  '';

              final interests = List<String>.from(data['interests'] ?? []);
              final isVerified = (data['isVerified'] as bool?) ?? false;
              final age = data['age'];
              final gender = (data['gender'] as String?) ?? '';

              // Live counts — show '…' while still loading
              final eventsCreated =
                  createdAsync.asData?.value.toString() ?? '…';
              final eventsAttended =
                  attendedAsync.asData?.value.toString() ?? '…';
              final friendsCount =
                  friendsCountAsync.asData?.value.toString() ?? '…';
              final circlesCount =
                  circlesCountAsync.asData?.value.toString() ?? '…';

              return _ProfileContent(
                displayName: displayName,
                email: email,
                city: city,
                bio: bio,
                photoUrl: photoUrl,
                interests: interests,
                eventsCreated: eventsCreated,
                eventsAttended: eventsAttended,
                friendsCount: friendsCount,
                circlesCount: circlesCount,
                isVerified: isVerified,
                age: age != null ? int.tryParse(age.toString()) : null,
                gender: gender,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  final String displayName;
  final String email;
  final String city;
  final String bio;
  final String photoUrl;
  final List<String> interests;
  final String eventsCreated;
  final String eventsAttended;
  final String friendsCount;
  final String circlesCount;
  final bool isVerified;
  final int? age;
  final String gender;

  const _ProfileContent({
    required this.displayName,
    required this.email,
    required this.city,
    required this.bio,
    required this.photoUrl,
    required this.interests,
    required this.eventsCreated,
    required this.eventsAttended,
    required this.friendsCount,
    required this.circlesCount,
    required this.isVerified,
    required this.age,
    required this.gender,
  });

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out', style: TheyDiTextStyles.headlineMedium),
        content: Text(
          'Are you sure you want to sign out?',
          style: TheyDiTextStyles.bodyMedium
              .copyWith(color: TheyDiColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign Out',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();

      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  Future<void> _openShareSheet(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    showProfileShareSheet(
      context,
      userId: uid,
      displayName: displayName,
      city: city,
      bio: bio,
      photoUrl: photoUrl,
      isPrivate:
          false, // Defaulting to false, adjust if there is a privacy flag
    );
  }

  Widget _buildProfileActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: TheyDiColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TheyDiTextStyles.labelSmall.copyWith(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';

    final List<String> identityParts = [];
    if (age != null) identityParts.add('$age');
    if (gender.isNotEmpty) identityParts.add(gender);
    final identityLine = identityParts.join(' • ');

    final showInterests = true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Profile',
                style: TheyDiTextStyles.displayMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _SettingsMenuButton(
                onSelected: (value) {
                  switch (value) {
                    case 'myEvents':
                      context.go(AppRoutes.myEvents);
                      break;
                    case 'myReviews':
                      context.push(AppRoutes.myReviews);
                      break;
                    case 'hostDashboard':
                      context.push(AppRoutes.hostDashboard);
                      break;
                    case 'helpSupport':
                      context.push(AppRoutes.helpSupport);
                      break;
                    case 'signOut':
                      _signOut(context, ref);
                      break;
                  }
                },
              ),
            ],
          ).animate().fade(duration: 300.ms),

          const SizedBox(height: 18),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: TheyDiColors.gradientPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: TheyDiColors.primary.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: photoUrl.isNotEmpty
                          ? Image.network(photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                    child: Text(initial,
                                        style: TheyDiTextStyles.displayLarge
                                            .copyWith(fontSize: 36, color: Colors.white)),
                                  ))
                          : Center(
                              child: Text(initial,
                                  style: TheyDiTextStyles.displayLarge
                                      .copyWith(fontSize: 36, color: Colors.white)),
                            ),
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 8),

                  // Show verify button only when not verified
                  if (!isVerified)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(AppRoutes.verifyProfile),
                        icon: const Icon(Icons.check, size: 14, color: Colors.white),
                        label: const Text('Verify Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TheyDiColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 36),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: TheyDiTextStyles.labelSmall
                              .copyWith(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: TheyDiTextStyles.headlineMedium.copyWith(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: TheyDiColors.warning,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ).animate(delay: 80.ms).fade(duration: 300.ms),

                    if (identityLine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(identityLine,
                              style: TheyDiTextStyles.labelMedium
                                  .copyWith(color: TheyDiColors.textSecondary))
                          .animate(delay: 100.ms)
                          .fade(duration: 300.ms),
                    ],

                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: TheyDiColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            city,
                            style: TheyDiTextStyles.labelSmall.copyWith(
                              color: TheyDiColors.textSecondary,
                            ),
                          ),
                        ],
                      ).animate(delay: 110.ms).fade(duration: 300.ms),
                    ],

                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(email,
                              style: TheyDiTextStyles.labelSmall
                                  .copyWith(color: TheyDiColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)
                          .animate(delay: 120.ms)
                          .fade(duration: 300.ms),
                    ],

                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(bio,
                              style: TheyDiTextStyles.bodyMedium.copyWith(
                                  color: TheyDiColors.textSecondary,
                                  height: 1.35),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis)
                          .animate(delay: 130.ms)
                          .fade(duration: 300.ms),
                    ],

                    if (interests.isNotEmpty && showInterests) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: interests
                            .map((i) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: TheyDiColors.gradientPrimary,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(i,
                                      style: TheyDiTextStyles.caption.copyWith(
                                          color: Colors.white, fontSize: 11)),
                                ))
                            .toList(),
                      ).animate(delay: 145.ms).fade(duration: 300.ms),
                    ],

                    const SizedBox(height: 10),

                    // Mobile: show buttons side-by-side with equal flexible width
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 600;
                        if (isWide) return const SizedBox.shrink();
                        return Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => context.push(AppRoutes.editprofile),
                                icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                                label: const Text('Edit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TheyDiColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: TheyDiTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openShareSheet(context),
                                icon: const Icon(Icons.share, size: 14, color: Colors.white),
                                label: const Text('Share'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TheyDiColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: TheyDiTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Web/Desktop: place buttons below the interests, left aligned with profile info
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              if (!isWide) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 104),
                    SizedBox(
                      width: 170,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(AppRoutes.editprofile),
                        icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TheyDiColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: TheyDiTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 170,
                      child: ElevatedButton.icon(
                        onPressed: () => _openShareSheet(context),
                        icon: const Icon(Icons.share, size: 14, color: Colors.white),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TheyDiColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: TheyDiTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          Column(
            children: [
              Row(
                children: [
                  _StatCard(
                    label: 'Events Created',
                    value: eventsCreated,
                    onTap: () => context.push(
                      AppRoutes.myEvents,
                      extra: {'tab': 2, 'filter': 'Hosted'},
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Events Attended',
                    value: eventsAttended,
                    onTap: () => context.push(
                      AppRoutes.myEvents,
                      extra: {'tab': 2, 'filter': 'Attended'},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatCard(
                    label: 'Friends',
                    value: friendsCount,
                    actionLabel: 'View Friends',
                    actionIcon: Icons.people_outline,
                    onTap: () => context.push(AppRoutes.friendsHub),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Friend Circles',
                    value: circlesCount,
                    actionLabel: 'View Circles',
                    actionIcon: Icons.group_outlined,
                    onTap: () => context.push(AppRoutes.circles),
                  ),
                ],
              ),
            ],
          ).animate(delay: 200.ms).fade(duration: 400.ms),

          const SizedBox(height: 20),

          _MenuItem(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            subtitle: 'Booking updates & reminders',
            onTap: () => context.push(AppRoutes.notifications),
          ).animate(delay: 260.ms).fade(duration: 300.ms),
          _MenuItem(
            icon: Icons.group_outlined,
            label: 'Friend Circle',
            subtitle: 'Chat with your groups',
            onTap: () => context.push(AppRoutes.circles),
          ).animate(delay: 270.ms).fade(duration: 300.ms),
          _MenuItem(
            icon: Icons.receipt_long_outlined,
            label: 'Payment History',
            subtitle: 'View your transactions',
            onTap: () => context.push(AppRoutes.paymenthistory),
          ).animate(delay: 280.ms).fade(duration: 300.ms),
          _MenuItem(
            icon: Icons.shield_outlined,
            label: 'Privacy & Security',
            subtitle: 'Control your visibility & data',
            onTap: () => context.push(AppRoutes.privacySafety),
          ).animate(delay: 290.ms).fade(duration: 300.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
// STAT CARD
// ══════════════════════════════════════
class _SettingsMenuButton extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _SettingsMenuButton({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: TheyDiColors.cardLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 44),
      itemBuilder: (context) => [
        _settingsItem(
          value: 'myEvents',
          icon: Icons.event_outlined,
          label: 'My Events',
        ),
        _settingsItem(
          value: 'myReviews',
          icon: Icons.star_outline,
          label: 'My Reviews',
        ),
        _settingsItem(
          value: 'hostDashboard',
          icon: Icons.analytics_outlined,
          label: 'Host Dashboard',
        ),
        _settingsItem(
          value: 'helpSupport',
          icon: Icons.help_outline,
          label: 'Help & Support',
        ),
        const PopupMenuDivider(height: 8),
        _settingsItem(
          value: 'signOut',
          icon: Icons.logout,
          label: 'Sign Out',
          color: TheyDiColors.error,
        ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: const Icon(
          Icons.settings_outlined,
          color: TheyDiColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }

  PopupMenuItem<String> _settingsItem({
    required String value,
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final itemColor = color ?? TheyDiColors.textSecondary;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: itemColor),
          const SizedBox(width: 10),
          Text(
            label,
            style: TheyDiTextStyles.bodyMedium.copyWith(
              color: color ?? TheyDiColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(
    vertical: 10,
    horizontal: 12,
  ),
  decoration: BoxDecoration(
    color: TheyDiColors.primary,
    borderRadius: BorderRadius.circular(10),
    boxShadow: [
      BoxShadow(
        color: TheyDiColors.primary.withValues(alpha: 0.18),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        icon,
        size: 15,
        color: Colors.white,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TheyDiTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  ),
),
    );
  }
}



class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final String actionLabel;
  final IconData actionIcon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.onTap,
    this.actionLabel = 'View history',
    this.actionIcon = Icons.history,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: TheyDiColors.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TheyDiTextStyles.headlineMedium.copyWith(
                  color: TheyDiColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: TheyDiTextStyles.labelSmall.copyWith(
                    color: TheyDiColors.textSecondary,
                  ),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(actionIcon, size: 10, color: TheyDiColors.primary),
                  const SizedBox(width: 3),
                  Text(actionLabel,
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.primary, fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// MENU ITEM
// ══════════════════════════════════════
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: TheyDiColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: TheyDiColors.divider),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: TheyDiColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: TheyDiColors.primary, size: 20),
          ),
          title: Text(
            label,
            style: TheyDiTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: TheyDiTextStyles.caption.copyWith(
                    color: TheyDiColors.textSecondary,
                  ),
                )
              : null,
          trailing: const Icon(Icons.arrow_forward_ios,
              size: 14, color: TheyDiColors.textMuted),
          onTap: onTap,
        ),
      ),
    );
  }
}
