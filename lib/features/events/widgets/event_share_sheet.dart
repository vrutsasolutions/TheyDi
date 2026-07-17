import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/theme/app_theme.dart';
import 'package:theydi/features/events/models/event_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EventShareSheet
//
// Usage (from EventDetailScreen or EventCard):
//   showEventShareSheet(context, event: event);
// ─────────────────────────────────────────────────────────────────────────────

const _eventShareBaseUrl = 'https://theydi.app/event';

String _eventLink(String eventId) => '$_eventShareBaseUrl/$eventId';

String _buildShareText(EventModel event) {
  final price = event.isFree ? 'Free' : '₹${event.price.toInt()}';
  return '🎉 ${event.title}\n'
      '📅 ${_formatShareDate(event.dateTime)}\n'
      '📍 ${event.venue}, ${event.city}\n'
      '💰 $price\n\n'
      'Join me on TheyDi 👇\n'
      '${_eventLink(event.id)}';
}

String _whatsAppUrl(EventModel event) {
  final text = Uri.encodeComponent(_buildShareText(event));
  return 'https://wa.me/?text=$text';
}

String _facebookUrl(EventModel event) {
  final link = Uri.encodeComponent(_eventLink(event.id));
  return 'https://www.facebook.com/sharer/sharer.php?u=$link';
}

String _twitterUrl(EventModel event) {
  final text = Uri.encodeComponent(
      '${event.title} – Join me on TheyDi!\n${_eventLink(event.id)}');
  return 'https://twitter.com/intent/tweet?text=$text';
}

Future<void> _copyShareLink(BuildContext context, EventModel event) async {
  await Clipboard.setData(ClipboardData(text: _eventLink(event.id)));
  if (context.mounted) {
    _showCopyToast(context, '🔗 Link copied to clipboard!');
  }
}

Future<bool> _launchExternal(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return true;
  }
  return false;
}

String _formatShareDate(DateTime dt) {
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '${_weekday(dt.weekday)}, ${months[dt.month - 1]} ${dt.day} · $hour:$minute $period';
}

String _weekday(int w) =>
    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];

void _showCopyToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message,
          style: const TextStyle(color: TheyDiColors.textPrimary)),
      backgroundColor: TheyDiColors.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ),
  );
}

void showEventShareSheet(BuildContext context, {required EventModel event}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EventShareSheet(event: event),
  );
}

class EventShareSheet extends StatefulWidget {
  final EventModel event;
  const EventShareSheet({super.key, required this.event});

  @override
  State<EventShareSheet> createState() => _EventShareSheetState();
}

class _EventShareSheetState extends State<EventShareSheet> {
  bool _linkCopied = false;

  Future<void> _copyLink() async {
    await _copyShareLink(context, widget.event);
    if (!mounted) return;
    setState(() => _linkCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _linkCopied = false);
  }

  Future<void> _shareExternal(String url, String platformName) async {
    if (platformName == 'Instagram') {
      final text = _buildShareText(widget.event);
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Link copied! Paste it in Instagram.',
            style: TextStyle(color: TheyDiColors.textPrimary)),
        backgroundColor: TheyDiColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }

    final launched = await _launchExternal(url);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open $platformName',
            style: const TextStyle(color: TheyDiColors.textPrimary)),
        backgroundColor: TheyDiColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else if (launched && mounted) {
      Navigator.pop(context); // close sheet after launching external app
      if (platformName != 'Instagram') {
        _showSuccessMessage();
      }
    }
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
        SizedBox(width: 8),
        Text('Event shared successfully! 🚀',
            style: TextStyle(color: TheyDiColors.textPrimary)),
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
      builder: (_) => _InAppFriendEventShareSheet(event: widget.event),
    );
  }

  void _shareInApp() {
    Navigator.pop(context);
    // Navigate to circles list so user can pick a circle to share the event in.
    // The circle chat screen can receive the event as an extra.
    context.push('/circles', extra: {'shareEvent': widget.event});
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final link = _eventLink(event.id);

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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header ──
          Row(children: [
            const Icon(Icons.share_outlined,
                color: TheyDiColors.primary, size: 22),
            const SizedBox(width: 10),
            Text('Share Event', style: TheyDiTextStyles.displayMedium),
          ]).animate().fade(duration: 250.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 4),
          Text(
            'Spread the word and help ${event.organizerName.split(' ').first} fill up the spots!',
            style: TheyDiTextStyles.caption
                .copyWith(color: TheyDiColors.textSecondary),
          ).animate(delay: 50.ms).fade(duration: 250.ms),

          const SizedBox(height: 20),

          // ── Event preview card ──
          _EventPreviewCard(event: event)
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
                onTap: () => _shareExternal(_whatsAppUrl(event), 'WhatsApp'),
                delay: 180,
              ),
              _ShareOption(
                assetLabel: 'FB',
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                onTap: () => _shareExternal(_facebookUrl(event), 'Facebook'),
                delay: 240,
              ),
              _ShareOption(
                assetLabel: 'X',
                label: 'X / Twitter',
                color: Colors.white,
                bgColor: Colors.black,
                onTap: () => _shareExternal(_twitterUrl(event), 'X'),
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
// Event Preview Card (shown inside share sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _EventPreviewCard extends StatelessWidget {
  final EventModel event;
  const _EventPreviewCard({required this.event});

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
        // Thumbnail
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: TheyDiColors.gradientPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: event.allImages.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(event.allImages.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _CategoryInitial(event.category)),
                )
              : _CategoryInitial(event.category),
        ),
        const SizedBox(width: 12),
        // Details
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.title,
                style: TheyDiTextStyles.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 12, color: TheyDiColors.textMuted),
              const SizedBox(width: 4),
              Text(
                _formatDate(event.dateTime),
                style: TheyDiTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 12, color: TheyDiColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${event.venue}, ${event.city}',
                    style: TheyDiTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        // Price badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: event.isFree
                ? Colors.green.withValues(alpha: 0.15)
                : TheyDiColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            event.isFree ? 'FREE' : '₹${event.price.toInt()}',
            style: TheyDiTextStyles.caption.copyWith(
              color: event.isFree ? Colors.green : TheyDiColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _CategoryInitial extends StatelessWidget {
  final String category;
  const _CategoryInitial(this.category);
  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          category.isNotEmpty ? category[0] : 'E',
          style: TheyDiTextStyles.displayMedium
              .copyWith(color: Colors.white, fontSize: 22),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Link Row — shows the URL + copy button
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
          child: Text(
            link,
            style: TheyDiTextStyles.caption
                .copyWith(color: TheyDiColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
// Individual share option button
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
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textSecondary, fontSize: 10)),
        ],
      )
          .animate(delay: Duration(milliseconds: delay))
          .fade(duration: 250.ms)
          .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// In-App Share Sheet — sends event_share message to selected friends
// ─────────────────────────────────────────────────────────────────────────────
class _InAppFriendEventShareSheet extends StatefulWidget {
  final EventModel event;
  const _InAppFriendEventShareSheet({required this.event});

  @override
  State<_InAppFriendEventShareSheet> createState() =>
      _InAppFriendEventShareSheetState();
}

class _InAppFriendEventShareSheetState
    extends State<_InAppFriendEventShareSheet> {
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
            .map((d) =>
                {'id': d.id, 'name': d.data()['displayName'] ?? 'Friend'})
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
    final link = _eventLink(widget.event.id);

    for (final friendUid in _selected) {
      final chatId = _generateChatId(myUid, friendUid);
      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);

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
        'type': 'event_share',
        'eventId': widget.event.id,
        'eventName': widget.event.title,
        'eventLink': link,
        'text':
            '🎉 $senderName shared an event: "${widget.event.title}"\n$link',
        'senderId': myUid,
        'senderName': senderName,
        'sentAt': Timestamp.now(),
        'readBy': [],
      });

      await chatRef.update({
        'lastMessage': 'Shared an event',
        'lastMessageSenderId': myUid,
        'updatedAt': Timestamp.now(),
      });
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(
              'Event shared to ${_selected.length} friend${_selected.length > 1 ? 's' : ''}! 🎉',
              style: const TextStyle(color: TheyDiColors.textPrimary)),
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
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
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
                      child:
                          const Icon(Icons.person, color: TheyDiColors.primary),
                    ),
                    title: Text(f['name'], style: TheyDiTextStyles.labelLarge),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: TheyDiColors.primary)
                        : const Icon(Icons.circle_outlined, color: Colors.grey),
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
