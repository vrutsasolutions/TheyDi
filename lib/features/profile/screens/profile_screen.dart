import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';

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

  Future<void> _signOut(BuildContext context) async {
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
      await FirebaseAuth.instance.signOut();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }

  Future<void> _openShareSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TheyDiColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share your profile', style: TheyDiTextStyles.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Share a link to your profile with friends and invite them to join your events.',
                style: TheyDiTextStyles.bodySmall
                    .copyWith(color: TheyDiColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text('Copy profile link',
                    style: TheyDiTextStyles.bodyMedium),
                onTap: () {
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text('Share via...', style: TheyDiTextStyles.bodyMedium),
                onTap: () {
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';

    final List<String> identityParts = [];
    if (age != null) identityParts.add('$age');
    if (gender.isNotEmpty) identityParts.add(gender);
    final identityLine = identityParts.join(' • ');

    // Whether to show interests chips (kept true by default)
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
                style: TheyDiTextStyles.headlineMedium.copyWith(
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
                      _signOut(context);
                      break;
                  }
                },
              ),
            ],
          ).animate().fade(duration: 300.ms),

          const SizedBox(height: 18),

          // ══════════════════════════════════════
          // HERO ROW — avatar left, all info right
          // ══════════════════════════════════════
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: TheyDiColors.gradientPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: TheyDiColors.primary.withValues(alpha: 0.35),
                      width: 2),
                ),
                child: ClipOval(
                  child: photoUrl.isNotEmpty
                      ? Image.network(photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                                child: Text(initial,
                                    style: TheyDiTextStyles.displayLarge
                                        .copyWith(
                                            fontSize: 36, color: Colors.white)),
                              ))
                      : Center(
                          child: Text(initial,
                              style: TheyDiTextStyles.displayLarge
                                  .copyWith(fontSize: 36, color: Colors.white)),
                        ),
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

              const SizedBox(width: 16),

              // Info column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + verified badge
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(displayName,
                                    style: TheyDiTextStyles.headlineMedium
                                        .copyWith(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: TheyDiColors.warning,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.check,
                                      size: 12, color: Colors.white),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ).animate(delay: 80.ms).fade(duration: 300.ms),

                    // Age • Gender
                    if (identityLine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(identityLine,
                              style: TheyDiTextStyles.labelMedium
                                  .copyWith(color: TheyDiColors.textSecondary))
                          .animate(delay: 100.ms)
                          .fade(duration: 300.ms),
                    ],

                    // Location
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

                    // Email
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

                    // Bio
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

                    // ── Interests — directly under bio, above buttons ──
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

                    // Edit Profile + Share Profile
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ProfileButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit Profile',
                          onTap: () => context.push(AppRoutes.editprofile),
                        ).animate(delay: 150.ms).fade(duration: 300.ms),
                        _ProfileButton(
                          icon: Icons.share_outlined,
                          label: 'Share Profile',
                          onTap: () => _openShareSheet(context),
                        ).animate(delay: 150.ms).fade(duration: 300.ms),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  _CompactCountBadge(
                    label: 'Friends',
                    value: friendsCount,
                    icon: Icons.people_outline,
                    onTap: () => context.push(AppRoutes.friendsHub),
                  ),
                  const SizedBox(height: 8),
                  _CompactCountBadge(
                    label: 'Circles',
                    value: circlesCount,
                    icon: Icons.group_outlined,
                    onTap: () => context.push(AppRoutes.circles),
                  ),
                ],
              ).animate(delay: 180.ms).fade(duration: 350.ms),
            ],
          ),

          const SizedBox(height: 24),

          // ══════════════════════════════════════
          // STAT CARDS — live counts, tappable
          // ══════════════════════════════════════
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
          ).animate(delay: 200.ms).fade(duration: 400.ms),

          const SizedBox(height: 28),

          _PremiumHostCard(
            onTap: () => context.push(AppRoutes.hostDashboard),
          ).animate(delay: 230.ms).fade(duration: 300.ms),

          const SizedBox(height: 20),

          // ══════════════════════════════════════
          // MENU ITEMS
          // ══════════════════════════════════════
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TheyDiTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumHostCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PremiumHostCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [TheyDiColors.primary, TheyDiColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: TheyDiColors.primary.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.workspace_premium_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Become Premium Host',
                    style: TheyDiTextStyles.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unlock better tools for events, insights, and earnings.',
                    style: TheyDiTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Start',
                style: TheyDiTextStyles.labelMedium.copyWith(
                  color: TheyDiColors.primary,
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

class _CompactCountBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _CompactCountBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: TheyDiColors.primary.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: TheyDiColors.primary.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: TheyDiColors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TheyDiTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: TheyDiColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TheyDiTextStyles.caption.copyWith(
                fontSize: 9,
                color: TheyDiColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
