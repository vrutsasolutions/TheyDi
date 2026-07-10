import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/friends_service.dart';

const _kReportReasons = [
  'Spam or unwanted messages',
  'Harassment or bullying',
  'Fake profile or impersonation',
  'Inappropriate content',
  'Scam or fraud',
  'Other',
];

class UserProfileScreen extends StatefulWidget {
  final String uid;
  final String? requestId;

  const UserProfileScreen({
    super.key,
    required this.uid,
    this.requestId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic> _userData = {};
  FriendStatus _status = FriendStatus.none;
  String _requestId = '';
  bool _loading = true;
  bool _processing = false;

  Map<String, dynamic> get _privacy =>
      (_userData['privacySettings'] as Map<String, dynamic>?) ?? const {};

  bool get _profileVisibleToOthers =>
      (_privacy['profileVisible'] as bool?) ?? true;

  bool get _showCity => (_privacy['showCity'] as bool?) ?? true;

  bool get _showInterests => (_privacy['showInterests'] as bool?) ?? true;

  bool get _showEventsAttended =>
      (_privacy['showEventsAttended'] as bool?) ?? true;

  bool get _allowMessages => (_privacy['allowMessages'] as bool?) ?? true;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isOwnProfile => widget.uid == _myUid;
  bool get _canMessageThisUser => _isOwnProfile || _allowMessages;

  @override
  void initState() {
    super.initState();
    if (widget.requestId != null) _requestId = widget.requestId!;
    _loadData();
  }

  Future<void> _loadData() async {
    final db = FirebaseFirestore.instance;
    final userDoc = await db.collection('users').doc(widget.uid).get();
    if (userDoc.exists) _userData = userDoc.data()!;

    if (_isOwnProfile) {
      if (mounted) {
        setState(() {
          _status = FriendStatus.self;
          _loading = false;
        });
      }
      return;
    }

    final friendDoc = await db
        .collection('users')
        .doc(_myUid)
        .collection('friends')
        .doc(widget.uid)
        .get();
    if (friendDoc.exists) {
      if (mounted) {
        setState(() {
          _status = FriendStatus.friends;
          _loading = false;
        });
      }
      return;
    }

    final sentSnap = await db
        .collection('users')
        .doc(widget.uid)
        .collection('friendRequests')
        .where('fromUid', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (sentSnap.docs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _status = FriendStatus.requestSent;
          _loading = false;
        });
      }
      return;
    }

    final receivedSnap = await db
        .collection('users')
        .doc(_myUid)
        .collection('friendRequests')
        .where('fromUid', isEqualTo: widget.uid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (receivedSnap.docs.isNotEmpty) {
      _requestId = receivedSnap.docs.first.id;
      if (mounted) {
        setState(() {
          _status = FriendStatus.requestReceived;
          _loading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _status = FriendStatus.none;
        _loading = false;
      });
    }
  }

  // ── Friend actions ──────────────────────────────────────────────────────────
  Future<void> _sendRequest() async {
    setState(() => _processing = true);
    await FriendsService.sendFriendRequest(
      toUid: widget.uid,
      toName: _userData['displayName'] ?? 'User',
    );
    if (mounted) {
      setState(() {
        _status = FriendStatus.requestSent;
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Friend request sent! 👋'),
          backgroundColor: Colors.green));
    }
  }

  Future<void> _accept() async {
    setState(() => _processing = true);
    await FriendsService.acceptFriendRequest(
      requestId: _requestId,
      fromUid: widget.uid,
      fromName: _userData['displayName'] ?? 'User',
    );
    if (mounted) {
      setState(() {
        _status = FriendStatus.friends;
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('You and ${_userData['displayName']} are now friends! 🎉'),
          backgroundColor: Colors.green));
    }
  }

  Future<void> _decline() async {
    setState(() => _processing = true);
    await FriendsService.declineFriendRequest(
      requestId: _requestId,
      myUid: _myUid,
    );
    if (mounted) {
      setState(() {
        _status = FriendStatus.none;
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request declined'), backgroundColor: Colors.grey));
    }
  }

  Future<void> _removeFriend() async {
    final confirmed = await _confirmDialog(
      title: 'Remove Friend?',
      body: 'Remove ${_userData['displayName']} from your friends?',
      confirm: 'Remove',
    );
    if (!confirmed) return;
    setState(() => _processing = true);
    await FriendsService.removeFriend(otherUid: widget.uid);
    if (mounted) {
      setState(() {
        _status = FriendStatus.none;
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Friend removed'), backgroundColor: Colors.grey));
    }
  }

  // ── Block ───────────────────────────────────────────────────────────────────
  Future<void> _blockUser() async {
    final confirmed = await _confirmDialog(
      title: 'Block ${_userData['displayName']}?',
      body:
          'They won\'t be able to send you friend requests or see your profile.',
      confirm: 'Block',
      confirmColor: Colors.red,
    );
    if (!confirmed) return;
    setState(() => _processing = true);
    await FriendsService.blockUser(otherUid: widget.uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_userData['displayName']} blocked'),
          backgroundColor: Colors.red));
      context.pop();
    }
  }

  // ── Report ──────────────────────────────────────────────────────────────────
  Future<void> _reportUser() async {
    String? selectedReason;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: TheyDiColors.divider),
          ),
          padding: const EdgeInsets.all(24),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flag_outlined,
                      color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Report ${_userData['displayName']}',
                    style: TheyDiTextStyles.headlineMedium),
              ]),
              const SizedBox(height: 6),
              Text('Select a reason for reporting',
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textSecondary)),
              const SizedBox(height: 16),
              ..._kReportReasons.map((reason) => GestureDetector(
                    onTap: () => setModalState(() => selectedReason = reason),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedReason == reason
                            ? Colors.red.withValues(alpha: 0.1)
                            : TheyDiColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedReason == reason
                              ? Colors.red.withValues(alpha: 0.5)
                              : TheyDiColors.divider,
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          selectedReason == reason
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 18,
                          color: selectedReason == reason
                              ? Colors.red
                              : TheyDiColors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Text(reason,
                            style: TheyDiTextStyles.bodySmall.copyWith(
                                color: selectedReason == reason
                                    ? Colors.red
                                    : TheyDiColors.textSecondary)),
                      ]),
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selectedReason != null
                        ? Colors.red
                        : TheyDiColors.divider,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: selectedReason == null
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _submitReport(selectedReason!);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Submit Report',
                        style: TheyDiTextStyles.labelMedium
                            .copyWith(color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    await FirebaseFirestore.instance.collection('reports').add({
      'reportedUid': widget.uid,
      'reportedName': _userData['displayName'],
      'reporterUid': _myUid,
      'reason': reason,
      'type': 'user',
      'createdAt': Timestamp.now(),
      'status': 'pending',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Report submitted. Thank you for helping keep TheyDi safe.'),
          backgroundColor: Colors.green));
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String body,
    required String confirm,
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TheyDiTextStyles.headlineMedium),
        content: Text(body,
            style: TheyDiTextStyles.bodyMedium
                .copyWith(color: TheyDiColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm,
                style:
                    TheyDiTextStyles.labelMedium.copyWith(color: confirmColor)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final name = (_userData['displayName'] as String?) ?? 'User';
    final bio = (_userData['bio'] as String?) ?? '';
    final city = (_userData['city'] as String?) ?? '';
    final photoUrl = (_userData['profileImageUrl'] as String?) ??
        (_userData['photoUrl'] as String?) ??
        '';

    final interests = List<String>.from(_userData['interests'] ?? []);

    final bool showPrivateRestricted =
        !_isOwnProfile && !_profileVisibleToOthers;

    // If profile isn't visible to others, mask all other public fields.
    final String maskedCity = showPrivateRestricted || !_showCity ? '' : city;
    final List<String> maskedInterests =
        (showPrivateRestricted || !_showInterests) ? [] : interests;

    final bool showEventsAttended =
        !(showPrivateRestricted || !_showEventsAttended);

    final age = _userData['age'];
    final gender = (_userData['gender'] as String?) ?? '';
    final isVerified = (_userData['isVerified'] as bool?) ?? false;
    final eventsAttended = (_userData['eventsAttended'] ?? 0).toString();
    final eventsCreated = (_userData['eventsCreated'] ?? 0).toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // ── NEW: rating fields ──
    final double avgRating =
        (_userData['avgRating'] as num?)?.toDouble() ?? 0.0;
    final int totalReviews = (_userData['totalReviews'] as num?)?.toInt() ?? 0;
    final bool hasRating = avgRating > 0;

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
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: TheyDiColors.primary))
              : Column(
                  children: [
                    // ── App Bar ──
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
                          Text(
                            _isOwnProfile ? 'My Profile' : 'Profile',
                            style: TheyDiTextStyles.displayMedium,
                          ),
                          const Spacer(),
                          if (_isOwnProfile)
                            GestureDetector(
                              onTap: () => context.push(AppRoutes.editprofile),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  gradient: TheyDiColors.gradientPrimary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('Edit',
                                    style: TheyDiTextStyles.caption.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                        ],
                      ),
                    ).animate().fade(duration: 300.ms),

                    // ── Scrollable Content ──
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 8),

                            // ── Avatar ──
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                gradient: TheyDiColors.gradientPrimary,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                    color: TheyDiColors.primary
                                        .withValues(alpha: 0.4),
                                    width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: photoUrl.isNotEmpty
                                    ? Image.network(photoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                            child: Text(initial,
                                                style: TheyDiTextStyles
                                                    .displayLarge
                                                    .copyWith(
                                                        fontSize: 40,
                                                        color: Colors.white))))
                                    : Center(
                                        child: Text(initial,
                                            style: TheyDiTextStyles.displayLarge
                                                .copyWith(
                                                    fontSize: 40,
                                                    color: Colors.white))),
                              ),
                            ).animate().scale(
                                duration: 400.ms, curve: Curves.elasticOut),

                            // ── NEW: rating badge below avatar ──
                            if (hasRating) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          Colors.amber.withValues(alpha: 0.45),
                                      width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      avgRating.toStringAsFixed(1),
                                      style: TheyDiTextStyles.caption.copyWith(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (totalReviews > 0) ...[
                                      const SizedBox(width: 3),
                                      Text(
                                        '($totalReviews ${totalReviews == 1 ? 'review' : 'reviews'})',
                                        style:
                                            TheyDiTextStyles.caption.copyWith(
                                          color: Colors.amber
                                              .withValues(alpha: 0.8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ).animate(delay: 90.ms).fade(duration: 300.ms),
                            ],

                            SizedBox(height: hasRating ? 12 : 16),

                            // ── Name + Verified + inline rating pill ──
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(name, style: TheyDiTextStyles.displayMedium),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                      color: TheyDiColors.warning,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.check,
                                      size: 12, color: Colors.white),
                                ),
                              ],
                              // ── NEW: compact star badge next to name ──
                              if (hasRating) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.amber
                                            .withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded,
                                            color: Colors.amber, size: 12),
                                        const SizedBox(width: 3),
                                        Text(
                                          avgRating.toStringAsFixed(1),
                                          style:
                                              TheyDiTextStyles.caption.copyWith(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ]),
                                ),
                              ],
                            ]).animate(delay: 80.ms).fade(duration: 300.ms),

                            if (age != null || gender.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (age != null) '$age',
                                  if (gender.isNotEmpty) gender
                                ].join(' • '),
                                style: TheyDiTextStyles.bodySmall.copyWith(
                                    color: TheyDiColors.textSecondary),
                              ).animate(delay: 100.ms).fade(duration: 300.ms),
                            ],

                            if (maskedCity.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 14, color: TheyDiColors.textMuted),
                                const SizedBox(width: 4),
                                Text(maskedCity,
                                    style: TheyDiTextStyles.caption),
                              ]).animate(delay: 120.ms).fade(duration: 300.ms),
                            ],

                            if (bio.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(bio,
                                      style: TheyDiTextStyles.bodySmall
                                          .copyWith(
                                              color: TheyDiColors.textSecondary,
                                              height: 1.5),
                                      textAlign: TextAlign.center)
                                  .animate(delay: 140.ms)
                                  .fade(duration: 300.ms),
                            ],

                            const SizedBox(height: 24),

                            // ── Stats ──
                            Row(children: [
                              if (showEventsAttended)
                                _StatCard(
                                    label: 'Events Attended',
                                    value: eventsAttended),
                              if (!showEventsAttended) const SizedBox(width: 0),
                              if (showEventsAttended) const SizedBox(width: 12),
                              _StatCard(
                                  label: 'Events Created',
                                  value: eventsCreated),
                            ]).animate(delay: 160.ms).fade(duration: 300.ms),

                            // ── Interests ──
                            if (maskedInterests.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Interests',
                                    style: TheyDiTextStyles.labelMedium
                                        .copyWith(
                                            color: TheyDiColors.textSecondary)),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: maskedInterests
                                      .map((i) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient:
                                                  TheyDiColors.gradientPrimary,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Text(i,
                                                style: TheyDiTextStyles.caption
                                                    .copyWith(
                                                        color: Colors.white)),
                                          ))
                                      .toList(),
                                ),
                              ).animate(delay: 180.ms).fade(duration: 300.ms),
                            ],

                            const SizedBox(height: 32),

                            // ── Action Buttons (other profiles only) ──
                            if (!_isOwnProfile) ...[
                              _buildPrimaryAction(),
                              const SizedBox(height: 10),
                              _buildSecondaryActions(),
                            ],

                            const SizedBox(height: 20),
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

  Widget _buildPrimaryAction() {
    final name = _userData['displayName'] ?? 'User';

    switch (_status) {
      case FriendStatus.friends:
        return Row(children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: TheyDiColors.gradientPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton.icon(
                onPressed: !_canMessageThisUser
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Messaging is disabled for this user.'),
                          ),
                        );
                      }
                    : () => context.push(AppRoutes.dmChat,
                        extra: {'otherUid': widget.uid, 'otherName': name}),
                icon: const Icon(Icons.chat_bubble_outline,
                    color: Colors.white, size: 18),
                label: const Text('Message',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: _processing ? null : _removeFriend,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: TheyDiColors.divider),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
            child: Text('Remove',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.textSecondary)),
          ),
        ]).animate(delay: 200.ms).fade(duration: 300.ms);

      case FriendStatus.requestReceived:
        return Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TheyDiColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: TheyDiColors.primary.withValues(alpha: 0.3)),
            ),
            child: Text('$name wants to connect with you',
                style: TheyDiTextStyles.bodySmall
                    .copyWith(color: TheyDiColors.textSecondary),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _processing ? null : _decline,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: TheyDiColors.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Decline',
                    style: TheyDiTextStyles.labelMedium
                        .copyWith(color: TheyDiColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: TheyDiColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: _processing ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Accept',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ]),
        ]).animate(delay: 200.ms).fade(duration: 300.ms);

      case FriendStatus.requestSent:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.hourglass_top,
                size: 16, color: TheyDiColors.textSecondary),
            label: Text('Request Pending',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.textSecondary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: TheyDiColors.divider),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ).animate(delay: 200.ms).fade(duration: 300.ms);

      case FriendStatus.none:
      default:
        return SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ElevatedButton.icon(
              onPressed: _processing ? null : _sendRequest,
              icon: _processing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add_outlined,
                      color: Colors.white, size: 18),
              label: Text(_processing ? 'Sending...' : 'Connect',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ).animate(delay: 200.ms).fade(duration: 300.ms);
    }
  }

  Widget _buildSecondaryActions() {
    return Column(children: [
      GestureDetector(
        onTap: _reportUser,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.flag_outlined, color: Colors.amber, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report User',
                        style: TheyDiTextStyles.labelMedium
                            .copyWith(color: Colors.amber)),
                    Text('Report inappropriate behavior',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textMuted)),
                  ]),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 13, color: Colors.amber.withValues(alpha: 0.6)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _blockUser,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.block_outlined, color: Colors.red, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Block User',
                        style: TheyDiTextStyles.labelMedium
                            .copyWith(color: Colors.red)),
                    Text('Hide and prevent contact',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textMuted)),
                  ]),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 13, color: Colors.red.withValues(alpha: 0.6)),
          ]),
        ),
      ),
    ]).animate(delay: 220.ms).fade(duration: 300.ms);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: Column(children: [
          Text(value, style: TheyDiTextStyles.displayMedium),
          const SizedBox(height: 4),
          Text(label,
              style: TheyDiTextStyles.caption, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
