import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../services/profile_share_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Usage (from ProfileScreen or UserProfileScreen):
//
//   showProfileShareSheet(
//     context,
//     userId: uid,
//     displayName: 'Sheerap',
//     city: 'Pune',
//     bio: 'A Party Liner.',
//     photoUrl: '',
//     isPrivate: false,   // pass true if user has privacy on
//   );
// ─────────────────────────────────────────────────────────────────────────────

void showProfileShareSheet(
  BuildContext context, {
  required String userId,
  required String displayName,
  required String city,
  required String bio,
  required String photoUrl,
  bool isPrivate = false,
}) {
  // ── Privacy guard: warn before sharing a private profile ──
  if (isPrivate) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.lock_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Text('Private Profile', style: TheyDiTextStyles.headlineMedium),
        ]),
        content: Text(
          'Your profile has some private settings enabled (city or interests hidden). '
          'The shared link will only show public information.',
          style: TheyDiTextStyles.bodySmall
              .copyWith(color: TheyDiColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.textSecondary)),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              _openSheet(context,
                  userId: userId,
                  displayName: displayName,
                  city: city,
                  bio: bio,
                  photoUrl: photoUrl);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: TheyDiColors.gradientPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Share Anyway',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
    return;
  }
  _openSheet(context,
      userId: userId,
      displayName: displayName,
      city: city,
      bio: bio,
      photoUrl: photoUrl);
}

void _openSheet(
  BuildContext context, {
  required String userId,
  required String displayName,
  required String city,
  required String bio,
  required String photoUrl,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProfileShareSheet(
      userId: userId,
      displayName: displayName,
      city: city,
      bio: bio,
      photoUrl: photoUrl,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ProfileShareSheet
// ─────────────────────────────────────────────────────────────────────────────
class ProfileShareSheet extends StatefulWidget {
  final String userId;
  final String displayName;
  final String city;
  final String bio;
  final String photoUrl;

  const ProfileShareSheet({
    super.key,
    required this.userId,
    required this.displayName,
    required this.city,
    required this.bio,
    required this.photoUrl,
  });

  @override
  State<ProfileShareSheet> createState() => _ProfileShareSheetState();
}

class _ProfileShareSheetState extends State<ProfileShareSheet> {
  bool _linkCopied = false;

  Future<void> _copyLink() async {
    await ProfileShareService.copyLink(context, widget.userId);
    if (!mounted) return;
    setState(() => _linkCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _linkCopied = false);
  }

  Future<void> _shareExternal(String url, String platformName) async {
    if (platformName == 'Instagram') {
      final text = ProfileShareService.buildShareText(
        userId: widget.userId,
        displayName: widget.displayName,
        city: widget.city,
        bio: widget.bio,
      );
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Link copied! Paste it in Instagram.', style: const TextStyle(color: TheyDiColors.textPrimary)),
        backgroundColor: TheyDiColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }

    final launched = await ProfileShareService.launchExternal(url);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open $platformName', style: const TextStyle(color: TheyDiColors.textPrimary)),
        backgroundColor: TheyDiColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else if (launched && mounted) {
      Navigator.pop(context);
      if (platformName != 'Instagram') {
        _showSuccessToast();
      }
    }
  }

  void _showSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
        SizedBox(width: 8),
        Text('Profile shared successfully! 🚀', style: const TextStyle(color: TheyDiColors.textPrimary)),
      ]),
      backgroundColor: TheyDiColors.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _shareToFriends() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InAppFriendProfileShareSheet(
        userId: widget.userId,
        displayName: widget.displayName,
      ),
    );
  }

  void _shareInApp() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InAppProfileShareSheet(
        userId: widget.userId,
        displayName: widget.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = ProfileShareService.profileLink(widget.userId);

    return Container(
      decoration: const BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: TheyDiColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header ──
          Row(children: [
            const Icon(Icons.person_outline,
                color: TheyDiColors.primary, size: 22),
            const SizedBox(width: 10),
            Text('Share Profile', style: TheyDiTextStyles.displayMedium),
          ]).animate().fade(duration: 250.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 4),
          Text(
            'Invite people to connect with ${widget.displayName.split(' ').first}!',
            style: TheyDiTextStyles.caption
                .copyWith(color: TheyDiColors.textSecondary),
          ).animate(delay: 50.ms).fade(duration: 250.ms),

          const SizedBox(height: 20),

          // ── Profile preview card ──
          _ProfilePreviewCard(
            userId: widget.userId,
            displayName: widget.displayName,
            city: widget.city,
            bio: widget.bio,
            photoUrl: widget.photoUrl,
          )
              .animate(delay: 80.ms)
              .fade(duration: 300.ms)
              .slideY(begin: 0.15, end: 0),

          const SizedBox(height: 20),

          // ── Link row ──
          _LinkRow(link: link, copied: _linkCopied, onCopy: _copyLink)
              .animate(delay: 120.ms)
              .fade(duration: 300.ms),

          const SizedBox(height: 20),

          Text('Share via',
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 14),

          // ── Share options ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareOption(
                icon: Icons.people_outline,
                label: 'Circles',
                color: TheyDiColors.primary,
                onTap: _shareInApp,
                delay: 150,
              ),
              _ShareOption(
                icon: Icons.person_outline,
                label: 'Friends',
                color: TheyDiColors.info,
                onTap: _shareToFriends,
                delay: 165,
              ),
              _ShareOption(
                assetLabel: 'WA',
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => _shareExternal(
                  ProfileShareService.whatsAppUrl(
                    userId: widget.userId,
                    displayName: widget.displayName,
                    city: widget.city,
                    bio: widget.bio,
                  ),
                  'WhatsApp',
                ),
                delay: 180,
              ),


              _ShareOption(
                assetLabel: 'FB',
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                onTap: () => _shareExternal(
                    ProfileShareService.facebookUrl(widget.userId),
                    'Facebook'),
                delay: 240,
              ),
              _ShareOption(
                assetLabel: 'X',
                label: 'X / Twitter',
                color: Colors.white,
                bgColor: Colors.black,
                onTap: () => _shareExternal(
                  ProfileShareService.twitterUrl(
                    userId: widget.userId,
                    displayName: widget.displayName,
                  ),
                  'X',
                ),
                delay: 270,
              ),
            ],
          ),

      const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: TheyDiColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// In-App Share Sheet — sends profile_share message to selected circles
// ─────────────────────────────────────────────────────────────────────────────
class _InAppProfileShareSheet extends StatefulWidget {
  final String userId;
  final String displayName;
  const _InAppProfileShareSheet(
      {required this.userId, required this.displayName});

  @override
  State<_InAppProfileShareSheet> createState() =>
      _InAppProfileShareSheetState();
}

class _InAppProfileShareSheetState
    extends State<_InAppProfileShareSheet> {
  List<Map<String, dynamic>> _circles = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadCircles();
  }

  Future<void> _loadCircles() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('circles')
        .where('memberUids', arrayContains: uid)
        .get();

    if (mounted) {
      setState(() {
        _circles = snap.docs
            .map((d) => {'id': d.id, 'name': d['name'] ?? 'Circle'})
            .toList();
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);

    final senderName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Someone';
    final link = ProfileShareService.profileLink(widget.userId);

    for (final circleId in _selected) {
      await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .collection('messages')
          .add({
        'type': 'profile_share',
        'userId': widget.userId,
        'userName': widget.displayName,
        'profileLink': link,
        'text':
            '👤 $senderName shared ${widget.displayName}\'s profile\n$link',
        'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'senderName': senderName,
        'sentAt': Timestamp.now(),
        'readBy': [],
      });
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(
              'Profile shared to ${_selected.length} circle${_selected.length > 1 ? 's' : ''}! 🎉',
              style: const TextStyle(color: TheyDiColors.textPrimary)),
        ]),
        backgroundColor: TheyDiColors.card,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: TheyDiColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          Row(children: [
            const Icon(Icons.send_outlined,
                color: TheyDiColors.primary, size: 20),
            const SizedBox(width: 10),
            Text('Send to Circles', style: TheyDiTextStyles.displayMedium),
            const Spacer(),
            if (_selected.isNotEmpty)
              GestureDetector(
                onTap: _sending ? null : _send,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: TheyDiColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Send (${_selected.length})',
                          style: TheyDiTextStyles.labelMedium
                              .copyWith(color: Colors.white)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text('Select circles to share this profile in',
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textSecondary)),
          const SizedBox(height: 16),

          if (_loading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: TheyDiColors.primary),
            ))
          else if (_circles.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'You have no circles to share to.',
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                children: _circles.map((c) {
                  final isSelected = _selected.contains(c['id']);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selected.remove(c['id']);
                      } else {
                        _selected.add(c['id']);
                      }
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? TheyDiColors.primary.withValues(alpha: 0.12)
                            : TheyDiColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? TheyDiColors.primary
                              : TheyDiColors.divider,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: TheyDiColors.gradientPrimary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              (c['name'] as String).isNotEmpty
                                  ? (c['name'] as String)[0].toUpperCase()
                                  : '?',
                              style: TheyDiTextStyles.labelMedium
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(c['name'],
                              style: TheyDiTextStyles.labelMedium),
                        ),
                        if (isSelected)
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: TheyDiColors.primary),
                            child: const Icon(Icons.check,
                                size: 13, color: Colors.white),
                          )
                        else
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: TheyDiColors.divider)),
                          ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: TheyDiColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Preview Card (shown inside share sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _ProfilePreviewCard extends StatelessWidget {
  final String userId;
  final String displayName;
  final String city;
  final String bio;
  final String photoUrl;

  const _ProfilePreviewCard({
    required this.userId,
    required this.displayName,
    required this.city,
    required this.bio,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: TheyDiColors.gradientPrimary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: photoUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                            child: Text(initial,
                                style: TheyDiTextStyles.displayMedium
                                    .copyWith(
                                        color: Colors.white, fontSize: 22)),
                          )),
                )
              : Center(
                  child: Text(initial,
                      style: TheyDiTextStyles.displayMedium
                          .copyWith(color: Colors.white, fontSize: 22)),
                ),
        ),
        const SizedBox(width: 14),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName,
                  style: TheyDiTextStyles.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (city.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: TheyDiColors.textMuted),
                  const SizedBox(width: 3),
                  Text(city, style: TheyDiTextStyles.caption),
                ]),
              ],
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(bio,
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),

        // TheyDi badge
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: TheyDiColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('TheyDi',
              style: TheyDiTextStyles.caption.copyWith(
                  color: TheyDiColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Link Row
// ─────────────────────────────────────────────────────────────────────────────
class _LinkRow extends StatelessWidget {
  final String link;
  final bool copied;
  final VoidCallback onCopy;
  const _LinkRow(
      {required this.link, required this.copied, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: copied
              ? Colors.green.withValues(alpha: 0.6)
              : TheyDiColors.divider,
        ),
      ),
      child: Row(children: [
        Icon(
          copied ? Icons.check_circle_outline : Icons.link_outlined,
          size: 16,
          color: copied ? Colors.green : TheyDiColors.textMuted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(link,
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onCopy,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: copied
                ? Text('Copied!',
                    key: const ValueKey('copied'),
                    style: TheyDiTextStyles.caption.copyWith(
                        color: Colors.green, fontWeight: FontWeight.w700))
                : Text('Copy',
                    key: const ValueKey('copy'),
                    style: TheyDiTextStyles.caption.copyWith(
                        color: TheyDiColors.primary,
                        fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Share Option button
// ─────────────────────────────────────────────────────────────────────────────
class _ShareOption extends StatelessWidget {
  final IconData? icon;
  final String? assetLabel;
  final String label;
  final Color color;
  final Color? bgColor;
  final VoidCallback onTap;
  final int delay;

  const _ShareOption({
    this.icon,
    this.assetLabel,
    required this.label,
    required this.color,
    this.bgColor,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor ?? color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: color.withValues(alpha: 0.25), width: 1),
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, color: color, size: 24)
                  : Text(
                      assetLabel!,
                      style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TheyDiTextStyles.caption.copyWith(
                  color: TheyDiColors.textSecondary, fontSize: 10)),
        ],
      )
          .animate(delay: Duration(milliseconds: delay))
          .fade(duration: 250.ms)
          .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1, 1)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// In-App Share Sheet — sends profile_share message to selected friends
// ─────────────────────────────────────────────────────────────────────────────
class _InAppFriendProfileShareSheet extends StatefulWidget {
  final String userId;
  final String displayName;
  const _InAppFriendProfileShareSheet(
      {required this.userId, required this.displayName});

  @override
  State<_InAppFriendProfileShareSheet> createState() =>
      _InAppFriendProfileShareSheetState();
}

class _InAppFriendProfileShareSheetState extends State<_InAppFriendProfileShareSheet> {
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friends')
        .get();

    if (mounted) {
      setState(() {
        _friends = snap.docs
            .map((d) => {'id': d.id, 'name': d.data()['displayName'] ?? 'Friend'})
            .toList();
        _loading = false;
      });
    }
  }

  String _generateChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final senderName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Someone';
    final link = ProfileShareService.profileLink(widget.userId);

    for (final friendUid in _selected) {
      final chatId = _generateChatId(myUid, friendUid);
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      
      final chatSnap = await chatRef.get();
      if (!chatSnap.exists) {
        await chatRef.set({
          'participants': [myUid, friendUid],
          'type': 'dm',
          'lastMessage': null,
          'lastMessageSenderId': null,
          'updatedAt': Timestamp.now(),
          'createdAt': Timestamp.now(),
        });
      }

      await chatRef.collection('messages').add({
        'type': 'profile_share',
        'userId': widget.userId,
        'userName': widget.displayName,
        'profileLink': link,
        'text': '👤 $senderName shared ${widget.displayName}\'s profile\n$link',
        'senderId': myUid,
        'senderName': senderName,
        'sentAt': Timestamp.now(),
        'readBy': [],
      });

      await chatRef.update({
        'lastMessage': 'Shared a profile',
        'lastMessageSenderId': myUid,
        'updatedAt': Timestamp.now(),
      });
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(
              'Profile shared to ${_selected.length} friend${_selected.length > 1 ? 's' : ''}! 🎉',
              style: const TextStyle(color: TheyDiColors.textPrimary)),
        ]),
        backgroundColor: TheyDiColors.card,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Share to Friends', style: TheyDiTextStyles.displaySmall),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_friends.isEmpty)
            Expanded(
              child: Center(
                child: Text('No friends yet.',
                    style: TheyDiTextStyles.bodyMedium
                        .copyWith(color: TheyDiColors.textSecondary)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  final f = _friends[index];
                  final isSelected = _selected.contains(f['id']);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: TheyDiColors.primary.withAlpha(25),
                      child: const Icon(Icons.person, color: TheyDiColors.primary),
                    ),
                    title: Text(f['name'], style: TheyDiTextStyles.labelLarge),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: TheyDiColors.primary)
                        : const Icon(Icons.circle_outlined,
                            color: Colors.grey),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selected.remove(f['id']);
                        } else {
                          _selected.add(f['id']);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TheyDiTextStyles.labelLarge
                            .copyWith(color: TheyDiColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TheyDiColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    onPressed: (_selected.isEmpty || _sending) ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Send (${_selected.length})',
                            style: TheyDiTextStyles.labelLarge
                                .copyWith(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
