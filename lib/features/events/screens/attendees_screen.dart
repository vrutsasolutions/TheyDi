// ─────────────────────────────────────────────────────────────────────────────
// CHANGES vs original attendees_screen.dart
//
//  1. Added import for leave_event_sheet.dart
//  2. Added _isAttendee getter to check if current user is an attendee
//  3. Added _hasLeft state bool to update UI after leaving
//  4. Added [Leave Event 🚪] button in AppBar top-right (attendees only)
//  5. onLeft callback: sets _hasLeft = true → button disappears, list refreshes
//  6. All existing Create Event Circle logic unchanged
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/friends_service.dart';
import '../../../core/services/event_circle_service.dart';
import '../models/event_model.dart';

// ── NEW import ──
import '../widgets/leave_event_sheet.dart';

class AttendeesScreen extends StatefulWidget {
  final EventModel event;
  const AttendeesScreen({super.key, required this.event});

  @override
  State<AttendeesScreen> createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends State<AttendeesScreen> {
  bool _creatingCircle = false;

  // ── NEW: tracks whether current user just left ──
  bool _hasLeft = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // True if current user is in the attendee list and NOT the host
  bool get _isAttendee {
    if (_hasLeft) return false;
    return widget.event.attendeeUids.contains(_myUid) &&
        _myUid != widget.event.creatorUid;
  }

  Future<void> _createEventCircle() async {
    final event = widget.event;

    final existing = await EventCircleService.getExistingEventCircle(event.id);
    if (existing != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event circle already exists! Opening it...'),
            backgroundColor: Colors.blue,
          ),
        );
        context.push(AppRoutes.circleChat, extra: existing);
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Create Event Circle?',
            style: TheyDiTextStyles.headlineMedium),
        content: Text(
          'This will create a group chat called '
          '"${event.title} Circle" with all '
          '${event.currentAttendees} attendees.',
          style: TheyDiTextStyles.bodyMedium
              .copyWith(color: TheyDiColors.textSecondary),
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
            child: Text('Create',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.primary)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _creatingCircle = true);

    try {
      final List<String> attendeeNames = [];
      for (final uid in event.attendeeUids) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          attendeeNames.add(userDoc.data()?['displayName'] ?? 'Member');
        } catch (_) {
          attendeeNames.add('Member');
        }
      }

      final circle = await EventCircleService.createEventCircle(
        event: event,
        attendeeUids: event.attendeeUids,
        attendeeNames: attendeeNames,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${circle.name}" created! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        context.push(AppRoutes.circleChat, extra: circle);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _creatingCircle = false);
  }

  // ── NEW: opens the leave event bottom sheet ──
  void _openLeaveSheet() {
    showLeaveEventSheet(
      context,
      event: widget.event,
      onLeft: () {
        // Mark as left so button disappears instantly
        setState(() => _hasLeft = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreateCircle = widget.event.currentAttendees >= 2;
    final eventStarted = widget.event.isOngoing || widget.event.isCompleted;

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
              // ── App Bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: TheyDiColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Attendees',
                              style: TheyDiTextStyles.displayMedium),
                          Text(
                            '${widget.event.currentAttendees} going to '
                            '"${widget.event.title}"',
                            style: TheyDiTextStyles.caption
                                .copyWith(color: TheyDiColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // ── NEW: Leave Event button (attendees only) ──
                    if (_isAttendee)
                      GestureDetector(
                        onTap: _openLeaveSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.exit_to_app,
                                  size: 14, color: Colors.red),
                              const SizedBox(width: 5),
                              Text('Leave',
                                  style: TheyDiTextStyles.caption.copyWith(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ).animate().fade(duration: 300.ms),

                    // ── Disabled leave warning if event started ──
                    if (!_isAttendee &&
                        !_hasLeft &&
                        eventStarted &&
                        widget.event.attendeeUids.contains(_myUid) &&
                        _myUid != widget.event.creatorUid)
                      Tooltip(
                        message: 'Event has started',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: TheyDiColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: TheyDiColors.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.exit_to_app,
                                  size: 14, color: TheyDiColors.textMuted),
                              const SizedBox(width: 5),
                              Text('Leave',
                                  style: TheyDiTextStyles.caption
                                      .copyWith(color: TheyDiColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              // ── Create Event Circle Button ──
              if (canCreateCircle)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: TheyDiColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _creatingCircle ? null : _createEventCircle,
                        icon: _creatingCircle
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.group_add_outlined,
                                color: Colors.white, size: 18),
                        label: Text(
                          _creatingCircle
                              ? 'Creating...'
                              : 'Create Event Circle',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ).animate(delay: 100.ms).fade(duration: 300.ms),

              const SizedBox(height: 12),

              // ── Attendees List ──
              Expanded(
                child: widget.event.attendeeUids.isEmpty ||
                        _hasLeft && widget.event.attendeeUids.length == 1
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey[700]),
                            const SizedBox(height: 16),
                            Text('No attendees yet',
                                style: TheyDiTextStyles.headlineMedium),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: widget.event.attendeeUids.length,
                        itemBuilder: (context, index) {
                          final uid = widget.event.attendeeUids[index];
                          // Hide the current user's card after leaving
                          if (_hasLeft && uid == _myUid) {
                            return const SizedBox.shrink();
                          }
                          return _AttendeeCard(
                            uid: uid,
                            myUid: _myUid,
                            isHost: uid == widget.event.creatorUid,
                          )
                              .animate(
                                  delay: Duration(milliseconds: 60 * index))
                              .fade(duration: 300.ms)
                              .slideY(begin: 0.1, end: 0);
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

// ── Attendee Card (unchanged) ─────────────────────────────────────────────────
class _AttendeeCard extends StatefulWidget {
  final String uid;
  final String myUid;
  final bool isHost;

  const _AttendeeCard({
    required this.uid,
    required this.myUid,
    required this.isHost,
  });

  @override
  State<_AttendeeCard> createState() => _AttendeeCardState();
}

class _AttendeeCardState extends State<_AttendeeCard> {
  FriendStatus _status = FriendStatus.none;
  bool _loading = true;
  bool _sending = false;
  String _requestId = '';

  @override
  void initState() {
    super.initState();
    if (widget.uid != widget.myUid) {
      _loadStatus();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStatus() async {
    final db = FirebaseFirestore.instance;

    final friendDoc = await db
        .collection('users')
        .doc(widget.myUid)
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
        .where('fromUid', isEqualTo: widget.myUid)
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
        .doc(widget.myUid)
        .collection('friendRequests')
        .where('fromUid', isEqualTo: widget.uid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (receivedSnap.docs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _status = FriendStatus.requestReceived;
          _requestId = receivedSnap.docs.first.id;
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

  Future<void> _sendRequest(String toName) async {
    setState(() => _sending = true);
    await FriendsService.sendFriendRequest(toUid: widget.uid, toName: toName);
    if (mounted) {
      setState(() {
        _status = FriendStatus.requestSent;
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Friend request sent! 👋'),
            backgroundColor: Colors.green),
      );
    }
  }

  void _showRespondSheet(BuildContext context, String fromName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TheyDiColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: TheyDiColors.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('$fromName wants to connect with you',
                  style: TheyDiTextStyles.labelLarge,
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: TheyDiColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(12)),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await FriendsService.acceptFriendRequest(
                          requestId: _requestId,
                          fromUid: widget.uid,
                          fromName: fromName);
                      if (mounted) {
                        setState(() => _status = FriendStatus.friends);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text('You and $fromName are now friends! 🎉'),
                            backgroundColor: Colors.green));
                      }
                    },
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Accept',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await FriendsService.declineFriendRequest(
                        requestId: _requestId, myUid: widget.myUid);
                    if (mounted) {
                      setState(() => _status = FriendStatus.none);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Request declined'),
                          backgroundColor: Colors.grey));
                    }
                  },
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Decline',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(widget.uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final name = data['displayName'] ?? 'User';
        final city = data['city'] ?? '';
        final photoUrl = data['profileImageUrl'] ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return GestureDetector(
          onTap: widget.uid != widget.myUid
              ? () => context.push(AppRoutes.userProfile, extra: {
                    'uid': widget.uid,
                    'requestId': _status == FriendStatus.requestReceived
                        ? _requestId
                        : null,
                  })
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TheyDiColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TheyDiColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      gradient: TheyDiColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(14)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: photoUrl.isNotEmpty
                        ? Image.network(photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                                child: Text(initial,
                                    style: TheyDiTextStyles.labelLarge
                                        .copyWith(color: Colors.white))))
                        : Center(
                            child: Text(initial,
                                style: TheyDiTextStyles.labelLarge
                                    .copyWith(color: Colors.white))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(name, style: TheyDiTextStyles.labelMedium),
                        if (widget.isHost) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                gradient: TheyDiColors.gradientPrimary,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('Host',
                                style: TheyDiTextStyles.caption.copyWith(
                                    color: Colors.white, fontSize: 10)),
                          ),
                        ],
                      ]),
                      if (city.isNotEmpty)
                        Row(children: [
                          Icon(Icons.location_on_outlined,
                              size: 11, color: TheyDiColors.textMuted),
                          const SizedBox(width: 3),
                          Text(city, style: TheyDiTextStyles.caption),
                        ]),
                    ],
                  ),
                ),
                if (widget.uid != widget.myUid)
                  _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: TheyDiColors.primary))
                      : GestureDetector(
                          onTap: () {},
                          behavior: HitTestBehavior.opaque,
                          child: _buildButton(context, name),
                        ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton(BuildContext context, String name) {
    switch (_status) {
      case FriendStatus.friends:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check, size: 14, color: Colors.green),
            const SizedBox(width: 4),
            Text('Connected',
                style: TheyDiTextStyles.caption.copyWith(
                    color: Colors.green, fontWeight: FontWeight.w600)),
          ]),
        );
      case FriendStatus.requestSent:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: TheyDiColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TheyDiColors.divider)),
          child: Text('Requested',
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textSecondary)),
        );
      case FriendStatus.requestReceived:
        return GestureDetector(
          onTap: () => _showRespondSheet(context, name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.4))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_outline, size: 14, color: Colors.blue),
              const SizedBox(width: 4),
              Text('Respond',
                  style: TheyDiTextStyles.caption.copyWith(
                      color: Colors.blue, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      case FriendStatus.none:
      default:
        return GestureDetector(
          onTap: _sending ? null : () => _sendRequest(name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: _sending ? null : TheyDiColors.gradientPrimary,
              color: _sending ? TheyDiColors.card : null,
              borderRadius: BorderRadius.circular(10),
              border: _sending ? Border.all(color: TheyDiColors.divider) : null,
            ),
            child: _sending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: TheyDiColors.primary))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_add_outlined,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Connect',
                        style: TheyDiTextStyles.caption.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
          ),
        );
    }
  }
}
