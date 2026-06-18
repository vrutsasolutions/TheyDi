import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_theme.dart';
import '../services/circle_share_service.dart';
import 'package:theydi/features/circles/models/circle_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Usage (from CircleInfoScreen):
//   showCircleShareSheet(context, circle: _circle);
// ─────────────────────────────────────────────────────────────────────────────

void showCircleShareSheet(BuildContext context, {required CircleModel circle}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CircleShareSheet(circle: circle),
  );
}

class CircleShareSheet extends StatefulWidget {
  final CircleModel circle;
  const CircleShareSheet({super.key, required this.circle});

  @override
  State<CircleShareSheet> createState() => _CircleShareSheetState();
}

class _CircleShareSheetState extends State<CircleShareSheet> {
  bool _linkCopied = false;

  Future<void> _copyLink() async {
    await CircleShareService.copyLink(context, widget.circle);
    if (!mounted) return;
    setState(() => _linkCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _linkCopied = false);
  }

  Future<void> _shareExternal(String url, String platformName) async {
    final launched = await CircleShareService.launchExternal(url);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open $platformName'),
        backgroundColor: TheyDiColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else if (launched && mounted) {
      Navigator.pop(context);
      _showSuccessToast();
    }
  }

  void _showSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
        SizedBox(width: 8),
        Text('Circle invite shared! 🚀'),
      ]),
      backgroundColor: TheyDiColors.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  /// In-app share: sends a circle_invite message to one or more of the
  /// current user's OTHER circles so friends can discover it.
  void _showInAppInviteSheet() {
    Navigator.pop(context); // close this sheet first
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InAppCircleInviteSheet(circle: widget.circle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final circle = widget.circle;
    final link = CircleShareService.circleLink(circle.id);

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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: TheyDiColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header ──
          Row(children: [
            const Icon(Icons.group_outlined, color: TheyDiColors.primary, size: 22),
            const SizedBox(width: 10),
            Text('Invite to Circle', style: TheyDiTextStyles.displayMedium),
          ]).animate().fade(duration: 250.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 4),
          Text(
            'Share "${circle.name}" and grow your circle!',
            style: TheyDiTextStyles.caption
                .copyWith(color: TheyDiColors.textSecondary),
          ).animate(delay: 50.ms).fade(duration: 250.ms),

          const SizedBox(height: 20),

          // ── Circle preview card ──
          _CirclePreviewCard(circle: circle)
              .animate(delay: 80.ms)
              .fade(duration: 300.ms)
              .slideY(begin: 0.15, end: 0),

          const SizedBox(height: 20),

          // ── Link row ──
          _LinkRow(link: link, copied: _linkCopied, onCopy: _copyLink)
              .animate(delay: 120.ms)
              .fade(duration: 300.ms),

          const SizedBox(height: 20),

          // ── Section label ──
          Text('Share via',
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 14),

          // ── Share option buttons ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ShareOption(
                icon: Icons.people_outline,
                label: 'In-App',
                color: TheyDiColors.primary,
                onTap: _showInAppInviteSheet,
                delay: 150,
              ),
              _ShareOption(
                assetLabel: 'WA',
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => _shareExternal(
                    CircleShareService.whatsAppUrl(circle), 'WhatsApp'),
                delay: 180,
              ),
              _ShareOption(
                assetLabel: 'IG',
                label: 'Instagram',
                color: const Color(0xFFE1306C),
                onTap: () => _shareExternal(
                    CircleShareService.instagramUrl(circle), 'Instagram'),
                delay: 210,
              ),
              _ShareOption(
                assetLabel: 'FB',
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                onTap: () => _shareExternal(
                    CircleShareService.facebookUrl(circle), 'Facebook'),
                delay: 240,
              ),
              _ShareOption(
                assetLabel: 'X',
                label: 'X / Twitter',
                color: Colors.white,
                bgColor: Colors.black,
                onTap: () => _shareExternal(
                    CircleShareService.twitterUrl(circle), 'X'),
                delay: 270,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Cancel ──
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
// In-App Invite Sheet — lets user forward the invite to their other circles
// ─────────────────────────────────────────────────────────────────────────────
class _InAppCircleInviteSheet extends StatefulWidget {
  final CircleModel circle;
  const _InAppCircleInviteSheet({required this.circle});

  @override
  State<_InAppCircleInviteSheet> createState() =>
      _InAppCircleInviteSheetState();
}

class _InAppCircleInviteSheetState extends State<_InAppCircleInviteSheet> {
  List<Map<String, dynamic>> _otherCircles = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadOtherCircles();
  }

  Future<void> _loadOtherCircles() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('circles')
        .where('memberUids', arrayContains: uid)
        .get();

    final others = snap.docs
        .where((d) => d.id != widget.circle.id)
        .map((d) => {'id': d.id, 'name': d['name'] ?? 'Circle'})
        .toList();

    if (mounted) {
      setState(() {
        _otherCircles = others;
        _loading = false;
      });
    }
  }

  Future<void> _sendInvites() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);

    final senderName = FirebaseAuth.instance.currentUser?.displayName ?? 'Someone';
    final link = CircleShareService.circleLink(widget.circle.id);

    for (final circleId in _selected) {
      await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .collection('messages')
          .add({
        'type': 'circle_invite',
        'circleId': widget.circle.id,
        'circleName': widget.circle.name,
        'circleLink': link,
        'text': '👥 $senderName invited you to join "${widget.circle.name}"\n$link',
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
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text('Invite sent to ${_selected.length} circle${_selected.length > 1 ? 's' : ''}! 🎉'),
        ]),
        backgroundColor: TheyDiColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: TheyDiColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Icon(Icons.send_outlined,
                  color: TheyDiColors.primary, size: 20),
              const SizedBox(width: 10),
              Text('Send to Circles', style: TheyDiTextStyles.displayMedium),
              const Spacer(),
              if (_selected.isNotEmpty)
                GestureDetector(
                  onTap: _sending ? null : _sendInvites,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: TheyDiColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Send (${_selected.length})',
                            style: TheyDiTextStyles.labelMedium
                                .copyWith(color: Colors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select circles to send the invite to',
            style: TheyDiTextStyles.caption
                .copyWith(color: TheyDiColors.textSecondary),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child:
                  CircularProgressIndicator(color: TheyDiColors.primary),
            ))
          else if (_otherCircles.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'You have no other circles to send this to.',
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                shrinkWrap: true,
                children: _otherCircles.map((c) {
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
                          width: 38, height: 38,
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
                            width: 22, height: 22,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: TheyDiColors.primary),
                            child: const Icon(Icons.check,
                                size: 13, color: Colors.white),
                          )
                        else
                          Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: TheyDiColors.divider)),
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
// Circle Preview Card
// ─────────────────────────────────────────────────────────────────────────────
class _CirclePreviewCard extends StatelessWidget {
  final CircleModel circle;
  const _CirclePreviewCard({required this.circle});

  @override
  Widget build(BuildContext context) {
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
          width: 54, height: 54,
          decoration: BoxDecoration(
            gradient: TheyDiColors.gradientPrimary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: circle.profileImageUrl != null &&
                  circle.profileImageUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    circle.profileImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _Initial(circle.initials),
                  ),
                )
              : _Initial(circle.initials),
        ),
        const SizedBox(width: 12),

        // Details
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Expanded(
                child: Text(circle.name,
                    style: TheyDiTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (circle.isEventCircle) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Event',
                      style: TheyDiTextStyles.caption.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 10)),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            if (circle.description.isNotEmpty)
              Text(circle.description,
                  style: TheyDiTextStyles.caption
                      .copyWith(color: TheyDiColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.people_outline,
                  size: 12, color: TheyDiColors.textMuted),
              const SizedBox(width: 4),
              Text(
                  '${circle.memberCount} member${circle.memberCount == 1 ? '' : 's'}',
                  style: TheyDiTextStyles.caption),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Initial extends StatelessWidget {
  final String text;
  const _Initial(this.text);
  @override
  Widget build(BuildContext context) => Center(
        child: Text(text,
            style: TheyDiTextStyles.displayMedium
                .copyWith(color: Colors.white, fontSize: 20)),
      );
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
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: bgColor ?? color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: color.withValues(alpha: 0.25), width: 1),
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
