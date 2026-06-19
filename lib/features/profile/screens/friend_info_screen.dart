import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/friends_service.dart';

const _kReportReasons = [
  'Spam or unwanted messages',
  'Harassment or bullying',
  'Fake profile or impersonation',
  'Inappropriate content',
  'Scam or fraud',
  'Other',
];

class FriendInfoScreen extends StatefulWidget {
  final String uid;
  final String displayName;

  const FriendInfoScreen({
    super.key,
    required this.uid,
    required this.displayName,
  });

  @override
  State<FriendInfoScreen> createState() => _FriendInfoScreenState();
}

class _FriendInfoScreenState extends State<FriendInfoScreen> {
  Map<String, dynamic>? _userData;
  FriendStatus _friendStatus = FriendStatus.none;
  List<Map<String, String>> _mutualCircles = [];
  bool _loading = true;
  bool _actionLoading = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String _generateChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('users').doc(widget.uid).get(),
      FriendsService.getFriendStatus(widget.uid),
      FriendsService.getMutualCircles(widget.uid),
    ]);

    if (!mounted) return;
    setState(() {
      _userData =
          (results[0] as DocumentSnapshot).data() as Map<String, dynamic>?;
      _friendStatus = results[1] as FriendStatus;
      _mutualCircles = results[2] as List<Map<String, String>>;
      _loading = false;
    });
  }

  Future<void> _handleFriendAction() async {
    setState(() => _actionLoading = true);
    try {
      switch (_friendStatus) {
        case FriendStatus.none:
          await FriendsService.sendFriendRequest(
            toUid: widget.uid,
            toName: widget.displayName,
          );
          break;
        case FriendStatus.requestReceived:
          await FriendsService.acceptFriendRequestByUid(
            otherUid: widget.uid,
            otherName: widget.displayName,
          );
          break;
        case FriendStatus.friends:
          final confirmed = await _confirmDialog(
            title: 'Remove Friend?',
            body: 'Remove ${widget.displayName} from your friends?',
            confirm: 'Remove',
          );
          if (confirmed) {
            await FriendsService.removeFriend(otherUid: widget.uid);
          }
          break;
        case FriendStatus.requestSent:
        case FriendStatus.self:
          break;
      }
      await _loadAll();
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _blockUser() async {
    final confirmed = await _confirmDialog(
      title: 'Block ${widget.displayName}?',
      body:
          'They won\'t be able to send friend requests or see your profile. This also removes the friendship.',
      confirm: 'Block',
      confirmColor: Colors.red,
    );
    if (!confirmed) return;

    setState(() => _actionLoading = true);
    await FriendsService.blockUser(otherUid: widget.uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${widget.displayName} blocked'),
            backgroundColor: Colors.red),
      );
      context.pop();
    }
  }

  // ── Clear Chat ──────────────────────────────────────────────────────────────
  Future<void> _clearChat() async {
    final confirmed = await _confirmDialog(
      title: 'Clear Chat?',
      body:
          'This will clear all messages from your view. ${widget.displayName} will still see the conversation.',
      confirm: 'Clear',
      confirmColor: Colors.orange,
    );
    if (!confirmed) return;

    final chatId = _generateChatId(_myUid, widget.uid);
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('clearedBy')
        .doc(_myUid)
        .set({'clearedAt': Timestamp.now()});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat cleared from your view'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ── Report User ─────────────────────────────────────────────────────────────
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
              Row(
                children: [
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
                  Text('Report ${widget.displayName}',
                      style: TheyDiTextStyles.headlineMedium),
                ],
              ),
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
                            : TheyDiColors.dark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedReason == reason
                              ? Colors.red.withValues(alpha: 0.5)
                              : TheyDiColors.divider,
                        ),
                      ),
                      child: Row(
                        children: [
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
                        ],
                      ),
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
      'reportedName': widget.displayName,
      'reporterUid': _myUid,
      'reason': reason,
      'type': 'user',
      'createdAt': Timestamp.now(),
      'status': 'pending',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Report submitted. Thank you for helping keep TieIn safe.'),
          backgroundColor: Colors.green,
        ),
      );
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
    final name = _userData?['displayName'] ?? widget.displayName;
    final city = _userData?['city'] ?? '';
    final bio = _userData?['bio'] ?? '';
    final photoUrl =
        _userData?['profileImageUrl'] ?? '';
    final interests = List<String>.from(_userData?['interests'] ?? []);
    final isVerified = (_userData?['isVerified'] as bool?) ?? false;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

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
                          Text('Profile',
                              style: TheyDiTextStyles.displayMedium),
                        ],
                      ),
                    ).animate().fade(duration: 300.ms),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // ── Avatar + Online ──
                          Center(
                            child: Stack(
                              children: [
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
                                            errorBuilder: (_, __, ___) =>
                                                Center(
                                                    child: Text(initial,
                                                        style: TheyDiTextStyles
                                                            .displayLarge
                                                            .copyWith(
                                                                fontSize: 40,
                                                                color: Colors
                                                                    .white))))
                                        : Center(
                                            child: Text(initial,
                                                style: TheyDiTextStyles
                                                    .displayLarge
                                                    .copyWith(
                                                        fontSize: 40,
                                                        color: Colors.white))),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(widget.uid)
                                        .snapshots(),
                                    builder: (context, snap) {
                                      final isOnline = (snap.data?.data()
                                                  as Map<String, dynamic>?)?[
                                              'isOnline'] ==
                                          true;
                                      return Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isOnline
                                              ? Colors.greenAccent
                                              : Colors.grey[600],
                                          border: Border.all(
                                              color: const Color(0xFF0D0D14),
                                              width: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ).animate().scale(
                              duration: 400.ms, curve: Curves.elasticOut),

                          const SizedBox(height: 14),

                          // ── Name + status ──
                          Center(
                            child: StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.uid)
                                  .snapshots(),
                              builder: (context, snap) {
                                final data =
                                    snap.data?.data() as Map<String, dynamic>?;
                                final isOnline = data?['isOnline'] == true;
                                final lastSeen = data?['lastSeen'] != null
                                    ? (data!['lastSeen'] as Timestamp).toDate()
                                    : null;

                                String statusLabel;
                                if (isOnline) {
                                  statusLabel = 'Online';
                                } else if (lastSeen != null) {
                                  final diff =
                                      DateTime.now().difference(lastSeen);
                                  if (diff.inMinutes < 5) {
                                    statusLabel = 'Last seen just now';
                                  } else if (diff.inHours < 1)
                                    statusLabel =
                                        'Last seen ${diff.inMinutes}m ago';
                                  else if (diff.inDays < 1)
                                    statusLabel =
                                        'Last seen ${diff.inHours}h ago';
                                  else
                                    statusLabel =
                                        'Last seen ${diff.inDays}d ago';
                                } else
                                  statusLabel = 'Offline';

                                return Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(name,
                                            style:
                                                TheyDiTextStyles.displayMedium),
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
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isOnline
                                                ? Colors.greenAccent
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(statusLabel,
                                            style: TheyDiTextStyles.caption
                                                .copyWith(
                                                    color: isOnline
                                                        ? Colors.greenAccent
                                                        : TheyDiColors
                                                            .textMuted)),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 8),

                          if (city.isNotEmpty)
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 13, color: TheyDiColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(city,
                                      style: TheyDiTextStyles.bodySmall
                                          .copyWith(
                                              color:
                                                  TheyDiColors.textSecondary)),
                                ],
                              ),
                            ),

                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: Text(bio,
                                  style: TheyDiTextStyles.bodySmall.copyWith(
                                      color: TheyDiColors.textSecondary),
                                  textAlign: TextAlign.center),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // ── Interests ──
                          if (interests.isNotEmpty) ...[
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: interests
                                  .map((i) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: TheyDiColors.primary
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(i,
                                            style: TheyDiTextStyles.caption
                                                .copyWith(
                                                    color: TheyDiColors.primary,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // ── Action Buttons ──
                          if (_friendStatus != FriendStatus.self) ...[
                            _FriendActionButton(
                              status: _friendStatus,
                              loading: _actionLoading,
                              onTap: _handleFriendAction,
                            ),
                            const SizedBox(height: 10),

                            // ── Clear Chat ──
                            _ActionTile(
                              icon: Icons.cleaning_services_outlined,
                              label: 'Clear Chat',
                              subtitle: 'Remove messages from your view',
                              color: Colors.orange,
                              onTap: _clearChat,
                            ),
                            const SizedBox(height: 8),

                            // ── Report User ──
                            _ActionTile(
                              icon: Icons.flag_outlined,
                              label: 'Report User',
                              subtitle: 'Report inappropriate behavior',
                              color: Colors.amber,
                              onTap: _reportUser,
                            ),
                            const SizedBox(height: 8),

                            // ── Block User ──
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _actionLoading ? null : _blockUser,
                                icon: const Icon(Icons.block,
                                    color: Colors.red, size: 18),
                                label: const Text('Block User',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // ── Mutual Circles ──
                          if (_mutualCircles.isNotEmpty) ...[
                            Text('Mutual Circles (${_mutualCircles.length})',
                                style: TheyDiTextStyles.labelLarge.copyWith(
                                    color: TheyDiColors.textSecondary)),
                            const SizedBox(height: 12),
                            ..._mutualCircles.map((circle) {
                              final cName = circle['name'] ?? 'Circle';
                              final cInitial = cName.isNotEmpty
                                  ? cName[0].toUpperCase()
                                  : '?';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: TheyDiColors.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: TheyDiColors.divider),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: TheyDiColors.gradientPrimary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(cInitial,
                                            style: TheyDiTextStyles.labelMedium
                                                .copyWith(color: Colors.white)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(cName,
                                        style: TheyDiTextStyles.labelMedium),
                                  ],
                                ),
                              );
                            }),
                          ],

                          const SizedBox(height: 40),
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

// ── Action Tile ───────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          TheyDiTextStyles.labelMedium.copyWith(color: color)),
                  Text(subtitle,
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

// ── Friend Action Button ──────────────────────────────────────────────────────
class _FriendActionButton extends StatelessWidget {
  final FriendStatus status;
  final bool loading;
  final VoidCallback onTap;

  const _FriendActionButton({
    required this.status,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;
    bool isOutlined = false;

    switch (status) {
      case FriendStatus.none:
        label = 'Add Friend';
        icon = Icons.person_add_outlined;
        break;
      case FriendStatus.requestReceived:
        label = 'Accept Request';
        icon = Icons.person_add_outlined;
        break;
      case FriendStatus.requestSent:
        label = 'Request Sent';
        icon = Icons.hourglass_top_outlined;
        isOutlined = true;
        break;
      case FriendStatus.friends:
        label = 'Remove Friend';
        icon = Icons.person_remove_outlined;
        isOutlined = true;
        break;
      case FriendStatus.self:
        return const SizedBox.shrink();
    }

    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed:
              (loading || status == FriendStatus.requestSent) ? null : onTap,
          icon: Icon(icon, size: 18, color: TheyDiColors.textSecondary),
          label: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: TheyDiColors.textSecondary)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: TheyDiColors.divider),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: TheyDiColors.gradientPrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton.icon(
          onPressed: loading ? null : onTap,
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(icon, size: 18, color: Colors.white),
          label: Text(label,
              style:
                  TheyDiTextStyles.labelMedium.copyWith(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}
