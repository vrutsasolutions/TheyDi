import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/profile_share_sheet.dart';

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

// ── Live count: communities ──
final _communitiesCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('communities')
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
    final communitiesCountAsync = ref.watch(_communitiesCountProvider);

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
              final isAdmin = (data['isAdmin'] as bool?) ?? false;
              final age = data['age'];
              final gender = (data['gender'] as String?) ?? '';

              // ── "What brings you here" — Social vs Professional ──
              // Set during signup (see SignupData); Professional adds a
              // job title / organization line, both may carry a social link.
              final purpose = (data['purpose'] as String?) ?? '';
              final jobTitle = (data['jobTitle'] as String?) ?? '';
              final organization = (data['organization'] as String?) ?? '';
              final socialPlatform = (data['socialPlatform'] as String?) ?? '';
              final socialLink = (data['socialLink'] as String?) ?? '';

              // Live counts — show '…' while still loading
              final eventsCreated =
                  createdAsync.asData?.value.toString() ?? '…';
              final eventsAttended =
                  attendedAsync.asData?.value.toString() ?? '…';
              final friendsCount =
                  friendsCountAsync.asData?.value.toString() ?? '…';
              final communitiesCount =
                  communitiesCountAsync.asData?.value.toString() ?? '…';

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
                communitiesCount: communitiesCount,
                isVerified: isVerified,
                age: age != null ? int.tryParse(age.toString()) : null,
                gender: gender,
                isAdmin: isAdmin,
                purpose: purpose,
                jobTitle: jobTitle,
                organization: organization,
                socialPlatform: socialPlatform,
                socialLink: socialLink,
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
  final String communitiesCount;
  final bool isVerified;
  final int? age;
  final String gender;
  final bool isAdmin;
  final String purpose;
  final String jobTitle;
  final String organization;
  final String socialPlatform;
  final String socialLink;

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
    required this.communitiesCount,
    required this.isVerified,
    required this.age,
    required this.gender,
    this.isAdmin = false,
    this.purpose = '',
    this.jobTitle = '',
    this.organization = '',
    this.socialPlatform = '',
    this.socialLink = '',
  });

  Future<void> _openSocialLink() async {
    if (socialLink.isEmpty) return;
    var link = socialLink.trim();
    if (!link.startsWith('http://') && !link.startsWith('https://')) {
      link = 'https://$link';
    }
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
      await NotificationService.setOnlineStatus(false);
      await FirebaseAuth.instance.signOut();
      if (context.mounted) context.go(AppRoutes.login);
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
                isAdmin: isAdmin, // ← ADD
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
                    case 'inviteFriends':
                      context.push(AppRoutes.inviteFriends);
                      break;
                    case 'signOut':
                      _signOut(context);
                      break;
                    case 'adminVerification':
                      context.push(AppRoutes.adminVerification);
                      break;
                    case 'adminPendingPayouts':
                      context.push(AppRoutes.adminPendingPayouts);
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
                                            .copyWith(
                                                fontSize: 36,
                                                color: Colors.white)),
                                  ))
                          : Center(
                              child: Text(initial,
                                  style: TheyDiTextStyles.displayLarge.copyWith(
                                      fontSize: 36, color: Colors.white)),
                            ),
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 8),
                  if (!isVerified) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) return;
                        context.push(
                          AppRoutes.faceVerification,
                          extra: {'userId': uid},
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_outlined,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text('Get Verified',
                                style: TheyDiTextStyles.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                                  // Was overridden up to 22px; using displaySmall (the shared
                                  // "page-title" size) keeps this consistent with every
                                  // other screen's header instead of being its own one-off.
                                  style: TheyDiTextStyles.displaySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // ── Verify button (only if not yet verified) ──

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

                    if (purpose.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _PurposeFloatingPill(
                        purpose: purpose,
                        jobTitle: jobTitle,
                        organization: organization,
                        socialPlatform: socialPlatform,
                        socialLink: socialLink,
                        onTapSocialLink: _openSocialLink,
                      ).animate(delay: 100.ms).fade(duration: 300.ms),
                    ],

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
                                onPressed: () =>
                                    context.push(AppRoutes.editprofile),
                                icon: const Icon(Icons.edit,
                                    size: 14, color: Colors.white),
                                label: const Text('Edit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TheyDiColors.primary,
                                  minimumSize: const Size(40, 45),
                                  maximumSize: const Size(40, 45),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle:
                                      TheyDiTextStyles.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openShareSheet(context),
                                icon: const Icon(Icons.share,
                                    size: 14, color: Colors.white),
                                label: const Text('Share'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TheyDiColors.primary,
                                  minimumSize: const Size(40, 45),
                                  maximumSize: const Size(40, 45),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle:
                                      TheyDiTextStyles.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

// Edit Profile + Share Profile
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
                      width: 100,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(AppRoutes.editprofile),
                        icon: const Icon(
                          Icons.edit,
                          size: 12,
                          color: Colors.white,
                        ),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TheyDiColors.primary,
                          minimumSize: const Size(100, 50),
                          maximumSize: const Size(100, 50),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(
                            horizontal: -4,
                            vertical: -4,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: TheyDiTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: ElevatedButton.icon(
                        onPressed: () => _openShareSheet(context),
                        icon: const Icon(
                          Icons.share,
                          size: 12,
                          color: Colors.white,
                        ),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TheyDiColors.primary,
                          minimumSize: const Size(100, 50),
                          maximumSize: const Size(100, 50),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(
                            horizontal: -4,
                            vertical: -4,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: TheyDiTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
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
                    label: 'Experiences Created',
                    value: eventsCreated,
                    icon: Icons.auto_awesome_outlined,
                    onTap: () => context.push(
                      AppRoutes.myEvents,
                      extra: {'tab': 2, 'filter': 'Hosted'},
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Experiences Attended',
                    value: eventsAttended,
                    icon: Icons.local_activity_outlined,
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
                    label: 'Connections',
                    value: friendsCount,
                    icon: Icons.people_alt_outlined,
                    actionLabel: 'View Connections',
                    actionIcon: Icons.people_outline,
                    onTap: () => context.push(AppRoutes.friendsHub),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Communities',
                    value: communitiesCount,
                    icon: Icons.diversity_3_outlined,
                    actionLabel: 'View Communities',
                    actionIcon: Icons.group_outlined,
                    onTap: () => context.push(
                      AppRoutes.friendsHub,
                      extra: {'initialTab': 2},
                    ),
                  ),
                ],
              ),
            ],
          ).animate(delay: 200.ms).fade(duration: 400.ms),

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
            icon: Icons.diversity_3_outlined,
            label: 'Communities',
            subtitle: 'Chat with your groups',
            onTap: () => context.push(
              AppRoutes.friendsHub,
              extra: {'initialTab': 2},
            ),
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
  final bool isAdmin; // ← ADD

  const _SettingsMenuButton({
    required this.onSelected,
    this.isAdmin = false, // ← ADD
  });

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
          icon: Icons.auto_awesome_outlined,
          label: 'My Experiences',
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
        _settingsItem(
          value: 'inviteFriends',
          icon: Icons.group_add_outlined,
          label: 'Invite Connections',
        ),
        const PopupMenuDivider(height: 8),
        if (isAdmin) ...[
          _settingsItem(
            value: 'adminVerification',
            icon: Icons.admin_panel_settings_outlined,
            label: 'Verification Requests',
            color: TheyDiColors.primary,
          ),
          _settingsItem(
            value: 'adminPendingPayouts',
            icon: Icons.account_balance_wallet_outlined,
            label: 'Pending Payouts',
            color: TheyDiColors.primary,
          ),
          const PopupMenuDivider(height: 8),
        ],
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

// ignore: unused_element
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
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: TheyDiColors.primary,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: TheyDiColors.primary.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TheyDiTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
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
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.onTap,
    this.actionLabel = 'View history',
    this.actionIcon = Icons.history,
    this.icon = Icons.insights_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                TheyDiColors.card,
                TheyDiColors.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: TheyDiColors.primary.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: TheyDiColors.primary.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: TheyDiColors.gradientPrimary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 12),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TheyDiTextStyles.labelLarge.copyWith(
                        color: TheyDiColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.1,
                      ),
                    ),
                    Text(label,
                        style: TheyDiTextStyles.caption.copyWith(
                          color: TheyDiColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════
// PURPOSE PILL — Social vs Professional (compact, floating)
// ══════════════════════════════════════
// Reflects the "what brings you here" choice made at signup (SignupData).
// Rendered as a single small pill under the name — not a full-width card —
// so it reads as a tag next to the verified badge rather than a section.
// Tapping it (when a social link exists) opens that link.
class _PurposeFloatingPill extends StatelessWidget {
  final String purpose;
  final String jobTitle;
  final String organization;
  final String socialPlatform;
  final String socialLink;
  final VoidCallback onTapSocialLink;

  const _PurposeFloatingPill({
    required this.purpose,
    required this.jobTitle,
    required this.organization,
    required this.socialPlatform,
    required this.socialLink,
    required this.onTapSocialLink,
  });

  bool get _isProfessional => purpose == 'Professional';

  IconData get _socialIcon {
    switch (socialPlatform) {
      case 'LinkedIn':
        return Icons.business_center_outlined;
      case 'Instagram':
        return Icons.camera_alt_outlined;
      case 'Twitter':
        return Icons.alternate_email;
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLine = _isProfessional
        ? [jobTitle, organization].where((s) => s.isNotEmpty).join(' at ')
        : '';
    final accent = _isProfessional ? TheyDiColors.primary : TheyDiColors.warning;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.75)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isProfessional ? Icons.work_outline : Icons.groups_outlined,
                size: 11,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                _isProfessional ? 'Professional' : 'Social',
                style: TheyDiTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        if (roleLine.isNotEmpty)
          Text(
            roleLine,
            style: TheyDiTextStyles.caption.copyWith(
              color: TheyDiColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        if (socialLink.isNotEmpty)
          GestureDetector(
            onTap: onTapSocialLink,
            child: Icon(_socialIcon, size: 14, color: TheyDiColors.textMuted),
          ),
      ],
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