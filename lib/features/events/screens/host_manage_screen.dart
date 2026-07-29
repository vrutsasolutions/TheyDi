// ─────────────────────────────────────────────────────────────────────────────
// CHANGES vs original host_manage_screen.dart
//
//  1. _PendingRequestCard now reads /events/{id}/pendingMeta/{uid}
//     and shows a coloured tag badge: Perfect | Age Mismatch | Gender Overflow
//     | Age + Gender on each pending request card.
//  2. _approveRequest also deletes the pendingMeta doc on approval.
//  3. _rejectRequest also deletes the pendingMeta doc on rejection.
//  4. All other logic (cancel, circle, approved attendees, etc.) unchanged.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:theydi/core/services/friends_service.dart';
import 'package:theydi/core/services/event_circle_service.dart';
import 'package:theydi/core/router/app_routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/event_model.dart';
import '../../circles/models/circle_model.dart';

class HostManageScreen extends ConsumerStatefulWidget {
  final String eventId;
  const HostManageScreen({super.key, required this.eventId});

  @override
  ConsumerState<HostManageScreen> createState() => _HostManageScreenState();
}

class _HostManageScreenState extends ConsumerState<HostManageScreen> {
  bool _isProcessing = false;
  CircleModel? _existingCircle;
  bool _checkingCircle = true;

  @override
  void initState() {
    super.initState();
    _checkExistingCircle();
  }

  Future<void> _checkExistingCircle() async {
    final circle =
        await EventCircleService.getExistingEventCircle(widget.eventId);
    if (mounted) {
      setState(() {
        _existingCircle = circle;
        _checkingCircle = false;
      });
    }
  }

  Future<void> _approveRequest(EventModel event, String userUid) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final eventRef =
          FirebaseFirestore.instance.collection('events').doc(widget.eventId);
      String userName = 'User';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userUid)
            .get();
        if (userDoc.exists) userName = userDoc.data()?['displayName'] ?? 'User';
      } catch (_) {}
      final hostName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'The host';

      if (event.isFree) {
        await eventRef.update({
          'pendingUids': FieldValue.arrayRemove([userUid]),
          'attendeeUids': FieldValue.arrayUnion([userUid]),
        });
        // Note: eventsAttended increment should be handled by a backend trigger to avoid permission denied
        await NotificationService.notifyRequestApproved(
            userUid: userUid,
            eventTitle: event.title,
            hostName: hostName,
            eventId: widget.eventId);

        await NotificationService.notifyAttendeeJoinedEmail(
          toUid: userUid,
          eventTitle: event.title,
          eventDate: DateFormat('EEE, MMM d · h:mm a').format(event.dateTime),
          eventVenue: event.venue,
          eventId: widget.eventId,
        );
        await NotificationService.notifyHostNewAttendeeEmail(
          hostUid: event.creatorUid,
          attendeeName: userName,
          eventTitle: event.title,
          amount: '0',
          eventId: widget.eventId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$userName approved! ✅'),
              backgroundColor: Colors.green));
        }
      } else {
        await eventRef.update({
          'pendingUids': FieldValue.arrayRemove([userUid]),
          'approvedPendingPaymentUids': FieldValue.arrayUnion([userUid]),
        });
        await NotificationService.send(
          toUid: userUid,
          title: 'Request approved — complete payment 💳',
          body:
              '$hostName approved your request for "${event.title}". Tap to pay and confirm your spot!',
          type: 'booking',
          eventId: widget.eventId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '$userName approved! They must complete payment to join.'),
              backgroundColor: Colors.green));
        }
      }

      // ── NEW: clean up pendingMeta doc ──
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('pendingMeta')
          .doc(userUid)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _rejectRequest(EventModel event, String userUid) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final eventRef =
          FirebaseFirestore.instance.collection('events').doc(widget.eventId);
      String userName = 'User';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userUid)
            .get();
        if (userDoc.exists) userName = userDoc.data()?['displayName'] ?? 'User';
      } catch (_) {}
      await eventRef.update({
        'pendingUids': FieldValue.arrayRemove([userUid]),
        'approvedPendingPaymentUids': FieldValue.arrayRemove([userUid]),
      });
      final hostName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'The host';
      await NotificationService.notifyRequestRejected(
          userUid: userUid,
          eventTitle: event.title,
          hostName: hostName,
          eventId: widget.eventId);

      // ── NEW: clean up pendingMeta doc ──
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('pendingMeta')
          .doc(userUid)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$userName\'s request declined'),
            backgroundColor: Colors.grey));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _cancelEvent(EventModel event) async {
    final hoursToStart = event.dateTime.difference(DateTime.now()).inHours;
    if (hoursToStart < 48) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Events can only be cancelled at least 48 hours before start time.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Event?', style: TheyDiTextStyles.headlineMedium),
        content: Text(
            'This will notify all ${event.currentAttendees} attendees. This cannot be undone.',
            style: TheyDiTextStyles.bodyMedium
                .copyWith(color: TheyDiColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Go Back',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: TheyDiColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Cancel Event',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('cancelEventAndRefund');
      await callable.call({'eventId': widget.eventId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Event cancelled and refunds initiated securely.'),
            backgroundColor: Colors.red));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isProcessing = false);
  }



  Future<void> _createEventCircle(EventModel event) async {
    if (_existingCircle != null) {
      context.push(AppRoutes.circleChat, extra: _existingCircle!);
      return;
    }
    if (event.attendeeUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No approved attendees yet'),
          backgroundColor: Colors.orange));
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
            'This will create a group chat called "${event.title} Circle" with all ${event.currentAttendees} approved attendees.',
            style: TheyDiTextStyles.bodyMedium
                .copyWith(color: TheyDiColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: TheyDiColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Create',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: TheyDiColors.primary))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
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
          attendeeNames: attendeeNames);
      if (mounted) {
        setState(() => _existingCircle = circle);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('"${circle.name}" created! 🎉'),
            backgroundColor: Colors.green));
        context.push(AppRoutes.circleChat, extra: circle);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  void _viewProfile(BuildContext context, String uid) {
    context.push(AppRoutes.userProfile, extra: {'uid': uid, 'requestId': null});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [TheyDiColors.cardLight, TheyDiColors.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter)),
        child: SafeArea(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: TheyDiColors.textPrimary),
                    onPressed: () => context.pop()),
                const SizedBox(width: 4),
                Text('Manage Event', style: TheyDiTextStyles.displayMedium),
              ]),
            ).animate().fade(duration: 300.ms),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .doc(widget.eventId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: TheyDiColors.primary));
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Center(
                        child: Text('Event not found',
                            style: TheyDiTextStyles.bodySmall));
                  }
                  final event = EventModel.fromFirestore(snapshot.data!);

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // ── Event Info Card ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: TheyDiColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: TheyDiColors.divider)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.title,
                                  style: TheyDiTextStyles.headlineMedium),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, runSpacing: 6, children: [
                                _StatPill(
                                    icon: Icons.people,
                                    label:
                                        '${event.currentAttendees}/${event.maxAttendees} attending',
                                    color: Colors.green),
                                _StatPill(
                                    icon: Icons.hourglass_top,
                                    label: '${event.pendingCount} pending',
                                    color: Colors.amber),
                                if (!event.isFree &&
                                    event.approvedPendingPaymentUids.isNotEmpty)
                                  _StatPill(
                                      icon: Icons.payment_outlined,
                                      label:
                                          '${event.approvedPendingPaymentUids.length} awaiting payment',
                                      color: Colors.blue),
                              ]),
                              if (event.currentAttendees >= 2) ...[
                                const SizedBox(height: 16),
                                _checkingCircle
                                    ? const Center(
                                        child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: TheyDiColors.primary)))
                                    : SizedBox(
                                        width: double.infinity,
                                        child: _existingCircle != null
                                            ? OutlinedButton.icon(
                                                onPressed: () => context.push(
                                                    AppRoutes.circleChat,
                                                    extra: _existingCircle!),
                                                icon: const Icon(
                                                    Icons.chat_bubble_outline,
                                                    color: TheyDiColors.primary,
                                                    size: 18),
                                                label: Text(
                                                    'Open Circle — ${_existingCircle!.name}',
                                                    style: TheyDiTextStyles
                                                        .labelMedium
                                                        .copyWith(
                                                            color: TheyDiColors
                                                                .primary)),
                                                style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(
                                                        color: TheyDiColors
                                                            .primary),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 12)),
                                              )
                                            : DecoratedBox(
                                                decoration: BoxDecoration(
                                                    gradient: TheyDiColors
                                                        .gradientPrimary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                child: ElevatedButton.icon(
                                                  onPressed: _isProcessing
                                                      ? null
                                                      : () =>
                                                          _createEventCircle(
                                                              event),
                                                  icon: _isProcessing
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  color: Colors
                                                                      .white))
                                                      : const Icon(
                                                          Icons
                                                              .group_add_outlined,
                                                          color: Colors.white,
                                                          size: 18),
                                                  label: Text(
                                                      _isProcessing
                                                          ? 'Creating...'
                                                          : 'Create Event Circle',
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      shadowColor:
                                                          Colors.transparent,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12)),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12)),
                                                ),
                                              ),
                                      ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _cancelEvent(event),
                                  icon: const Icon(Icons.cancel_outlined,
                                      color: Colors.red, size: 18),
                                  label: const Text('Cancel Event',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12)),
                                ),
                              ),
                            ]),
                      ).animate(delay: 100.ms).fade(duration: 400.ms),

                      const SizedBox(height: 24),

                      // ── Pending Requests ──
                      Text('Pending requests',
                              style: TheyDiTextStyles.labelLarge)
                          .animate(delay: 150.ms)
                          .fade(duration: 300.ms),
                      const SizedBox(height: 4),
                      Text('Approve or decline join requests',
                              style: TheyDiTextStyles.caption
                                  .copyWith(color: TheyDiColors.textSecondary))
                          .animate(delay: 170.ms)
                          .fade(duration: 300.ms),
                      const SizedBox(height: 12),

                      if (event.pendingUids.isEmpty)
                        _buildEmptyPending()
                      else
                        ...List.generate(event.pendingUids.length, (index) {
                          final uid = event.pendingUids[index];
                          return _PendingRequestCard(
                            userUid: uid,
                            eventId: widget.eventId, // ← NEW
                            isPaidEvent: !event.isFree,
                            onApprove: () => _approveRequest(event, uid),
                            onReject: () => _rejectRequest(event, uid),
                            onViewProfile: () => _viewProfile(context, uid),
                            isProcessing: _isProcessing,
                          )
                              .animate(
                                  delay:
                                      Duration(milliseconds: 200 + 50 * index))
                              .fade(duration: 300.ms)
                              .slideY(begin: 0.1, end: 0);
                        }),

                      // ── Awaiting Payment ──
                      if (!event.isFree &&
                          event.approvedPendingPaymentUids.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Awaiting payment',
                                style: TheyDiTextStyles.labelLarge)
                            .animate(delay: 250.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 4),
                        Text('Approved — waiting for user to complete payment',
                                style: TheyDiTextStyles.caption.copyWith(
                                    color: TheyDiColors.textSecondary))
                            .animate(delay: 270.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 12),
                        ...event.approvedPendingPaymentUids.map((uid) =>
                            _AwaitingPaymentCard(
                                    userUid: uid,
                                    onViewProfile: () =>
                                        _viewProfile(context, uid))
                                .animate(delay: 300.ms)
                                .fade(duration: 300.ms)),
                      ],

                      const SizedBox(height: 24),

                      // ── Approved Attendees ──
                      Text('Approved attendees',
                              style: TheyDiTextStyles.labelLarge)
                          .animate(delay: 300.ms)
                          .fade(duration: 300.ms),
                      const SizedBox(height: 12),

                      if (event.attendeeUids.isEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                                child: Text('No attendees yet',
                                    style: TheyDiTextStyles.caption.copyWith(
                                        color: TheyDiColors.textMuted))))
                      else
                        ...List.generate(event.attendeeUids.length, (index) {
                          final uid = event.attendeeUids[index];
                          return _AttendeeCard(
                                  userUid: uid,
                                  isHostUid: event.creatorUid,
                                  onViewProfile: () =>
                                      _viewProfile(context, uid))
                              .animate(
                                  delay:
                                      Duration(milliseconds: 350 + 40 * index))
                              .fade(duration: 300.ms);
                        }),

                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyPending() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
          child: Column(children: [
        Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[700]),
        const SizedBox(height: 12),
        Text('No pending requests', style: TheyDiTextStyles.headlineMedium),
        const SizedBox(height: 4),
        Text('All caught up!',
            style: TheyDiTextStyles.caption
                .copyWith(color: TheyDiColors.textSecondary)),
      ])),
    );
  }
}

// ── Stat Pill ─────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TheyDiTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _PendingRequestCard — NOW reads pendingMeta tag from Firestore
// ─────────────────────────────────────────────────────────────────────────────
class _PendingRequestCard extends StatefulWidget {
  final String userUid;
  final String eventId;
  final bool isPaidEvent;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewProfile;
  final bool isProcessing;

  const _PendingRequestCard({
    required this.userUid,
    required this.eventId,
    required this.isPaidEvent,
    required this.onApprove,
    required this.onReject,
    required this.onViewProfile,
    required this.isProcessing,
  });

  @override
  State<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends State<_PendingRequestCard> {
  late Future<List<DocumentSnapshot>> _future;

  @override
  void initState() {
    super.initState();
    _future = Future.wait([
      FirebaseFirestore.instance.collection('users').doc(widget.userUid).get(),
      FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('pendingMeta')
          .doc(widget.userUid)
          .get(),
    ]);
  }

  // ── Tag colour mapping ──
  static Color _tagColor(String tag) {
    switch (tag) {
      case 'Perfect':
        return Colors.green;
      case 'Age Mismatch':
        return Colors.orange;
      case 'Gender Overflow':
        return Colors.blue;
      case 'Age + Gender':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static IconData _tagIcon(String tag) {
    switch (tag) {
      case 'Perfect':
        return Icons.check_circle_outline;
      case 'Age Mismatch':
        return Icons.cake_outlined;
      case 'Gender Overflow':
        return Icons.people_outline;
      case 'Age + Gender':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _future,
      builder: (context, snapshot) {
        final userSnap = snapshot.data?[0];
        final metaSnap = snapshot.data?[1];

        final userData = userSnap?.data() as Map<String, dynamic>? ?? {};
        final metaData = metaSnap?.data() as Map<String, dynamic>? ?? {};

        final name = userData['displayName'] ?? 'Loading...';
        final email = userData['email'] ?? '';
        final tag = (metaData['tag'] as String?) ?? '…';

        final tagColor = tag == '…' ? Colors.transparent : _tagColor(tag);
        final tagIcon = tag == '…' ? Icons.hourglass_top : _tagIcon(tag);

        // Border colour: orange for mismatches, green for perfect
        final borderColor = (tag == 'Perfect' || tag == '…')
            ? Colors.amber.withValues(alpha: 0.3)
            : tagColor.withValues(alpha: 0.4);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // ── Clickable: avatar + name ──
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onViewProfile,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            gradient: TheyDiColors.gradientPrimary,
                            borderRadius: BorderRadius.circular(12)),
                        child: Center(
                            child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TheyDiTextStyles.labelLarge
                                    .copyWith(color: Colors.white)))),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(name, style: TheyDiTextStyles.labelMedium),
                            const SizedBox(width: 4),
                            Icon(Icons.open_in_new,
                                size: 11, color: TheyDiColors.textMuted),
                          ]),
                          if (email.isNotEmpty)
                            Text(email, style: TheyDiTextStyles.caption),
                          if (widget.isPaidEvent) ...[
                            const SizedBox(height: 2),
                            Text('Approving will require payment',
                                style: TheyDiTextStyles.caption.copyWith(
                                    color: Colors.blue, fontSize: 10)),
                          ],
                        ]),
                  ]),
                ),
              ),

              const Spacer(),

              // ── Reject ──
              GestureDetector(
                onTap: widget.isProcessing ? null : widget.onReject,
                child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10)),
                    child:
                        const Icon(Icons.close, color: Colors.red, size: 20)),
              ),
              const SizedBox(width: 8),
              // ── Approve ──
              GestureDetector(
                onTap: widget.isProcessing ? null : widget.onApprove,
                child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10)),
                    child:
                        const Icon(Icons.check, color: Colors.green, size: 20)),
              ),
            ]),

            // ── NEW: Tag badge row ──────────────────────────────────────────
            if (tag != '…') ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tagColor.withValues(alpha: 0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(tagIcon, size: 13, color: tagColor),
                  const SizedBox(width: 5),
                  Text(tag,
                      style: TheyDiTextStyles.caption.copyWith(
                          color: tagColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11)),
                  if (tag == 'Age Mismatch' || tag == 'Age + Gender') ...[
                    const SizedBox(width: 6),
                    Text('— outside age group',
                        style: TheyDiTextStyles.caption.copyWith(
                            color: tagColor.withValues(alpha: 0.8),
                            fontSize: 10)),
                  ],
                  if (tag == 'Gender Overflow' || tag == 'Age + Gender') ...[
                    const SizedBox(width: 6),
                    Text('— gender slot full',
                        style: TheyDiTextStyles.caption.copyWith(
                            color: tagColor.withValues(alpha: 0.8),
                            fontSize: 10)),
                  ],
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }
}

// ── Awaiting Payment Card (unchanged) ────────────────────────────────────────
class _AwaitingPaymentCard extends StatefulWidget {
  final String userUid;
  final VoidCallback onViewProfile;
  const _AwaitingPaymentCard(
      {required this.userUid, required this.onViewProfile});

  @override
  State<_AwaitingPaymentCard> createState() => _AwaitingPaymentCardState();
}

class _AwaitingPaymentCardState extends State<_AwaitingPaymentCard> {
  late Future<DocumentSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final name = data['displayName'] ?? 'Loading...';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: TheyDiColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3))),
          child: Row(children: [
            MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                    onTap: widget.onViewProfile,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              gradient: TheyDiColors.gradientPrimary,
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(
                              child: Text(
                                  name.isNotEmpty && name != 'Loading...'
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: TheyDiTextStyles.labelMedium
                                      .copyWith(color: Colors.white)))),
                      const SizedBox(width: 12),
                      Row(children: [
                        Text(name, style: TheyDiTextStyles.labelMedium),
                        const SizedBox(width: 4),
                        Icon(Icons.open_in_new,
                            size: 11, color: TheyDiColors.textMuted)
                      ]),
                    ]))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.hourglass_top_outlined,
                    size: 11, color: Colors.blue),
                const SizedBox(width: 4),
                Text('Awaiting payment',
                    style: TheyDiTextStyles.caption.copyWith(
                        color: Colors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ── Attendee Card (unchanged) ─────────────────────────────────────────────────
class _AttendeeCard extends StatefulWidget {
  final String userUid;
  final String isHostUid;
  final VoidCallback onViewProfile;
  const _AttendeeCard(
      {required this.userUid,
      required this.isHostUid,
      required this.onViewProfile});
  @override
  State<_AttendeeCard> createState() => _AttendeeCardState();
}

class _AttendeeCardState extends State<_AttendeeCard> {
  FriendStatus _status = FriendStatus.none;
  bool _loadingStatus = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || myUid == widget.userUid) {
      if (mounted) setState(() => _loadingStatus = false);
      return;
    }
    final db = FirebaseFirestore.instance;
    final friendDoc = await db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(widget.userUid)
        .get();
    if (friendDoc.exists) {
      if (mounted) {
        setState(() {
          _status = FriendStatus.friends;
          _loadingStatus = false;
        });
      }
      return;
    }
    final sentSnap = await db
        .collection('users')
        .doc(widget.userUid)
        .collection('friendRequests')
        .where('fromUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (sentSnap.docs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _status = FriendStatus.requestSent;
          _loadingStatus = false;
        });
      }
      return;
    }
    final receivedSnap = await db
        .collection('users')
        .doc(myUid)
        .collection('friendRequests')
        .where('fromUid', isEqualTo: widget.userUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (receivedSnap.docs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _status = FriendStatus.requestReceived;
          _loadingStatus = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _status = FriendStatus.none;
        _loadingStatus = false;
      });
    }
  }

  Future<void> _sendRequest(String toName) async {
    setState(() => _sending = true);
    await FriendsService.sendFriendRequest(
        toUid: widget.userUid, toName: toName);
    if (mounted) {
      setState(() {
        _status = FriendStatus.requestSent;
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Friend request sent! 👋'),
          backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMe = widget.userUid == myUid;
    final isHostMember = widget.userUid == widget.isHostUid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final name = data['displayName'] ?? 'Loading...';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: TheyDiColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TheyDiColors.divider)),
          child: Row(children: [
            MouseRegion(
                cursor:
                    isMe ? SystemMouseCursors.basic : SystemMouseCursors.click,
                child: GestureDetector(
                    onTap: isMe ? null : widget.onViewProfile,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              gradient: TheyDiColors.gradientPrimary,
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(
                              child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TheyDiTextStyles.labelLarge
                                      .copyWith(color: Colors.white)))),
                      const SizedBox(width: 10),
                      Row(children: [
                        Text(name, style: TheyDiTextStyles.labelMedium),
                        if (!isMe) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.open_in_new,
                              size: 11, color: TheyDiColors.textMuted)
                        ],
                      ]),
                    ]))),
            const Spacer(),
            isHostMember
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: TheyDiColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('Admin',
                        style: TheyDiTextStyles.caption.copyWith(
                            color: TheyDiColors.primary,
                            fontWeight: FontWeight.w600)))
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('Approved',
                        style: TheyDiTextStyles.caption.copyWith(
                            color: Colors.green, fontWeight: FontWeight.w600))),
            if (!isMe) ...[
              const SizedBox(width: 8),
              _loadingStatus
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: TheyDiColors.primary))
                  : _buildConnectButton(name),
            ],
          ]),
        );
      },
    );
  }

  Widget _buildConnectButton(String name) {
    switch (_status) {
      case FriendStatus.friends:
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check, size: 12, color: Colors.green),
              const SizedBox(width: 4),
              Text('Connected',
                  style: TheyDiTextStyles.caption.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 10)),
            ]));
      case FriendStatus.requestSent:
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: TheyDiColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TheyDiColors.divider)),
            child: Text('Requested',
                style: TheyDiTextStyles.caption.copyWith(
                    color: TheyDiColors.textSecondary, fontSize: 10)));
      default:
        return GestureDetector(
            onTap: _sending ? null : () => _sendRequest(name),
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    gradient: TheyDiColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(8)),
                child: _sending
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Connect',
                        style: TheyDiTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10))));
    }
  }
}
