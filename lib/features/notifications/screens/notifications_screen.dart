import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/friends_service.dart';
import '../../events/models/event_model.dart';

// ── Notification Model ──
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? eventId;
  final String? fromUid;
  final String? circleId;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.eventId,
    this.fromUid,
    this.circleId,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'system',
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      eventId: data['eventId'],
      fromUid: data['fromUid'],
      circleId: data['circleId'],
    );
  }

  IconData get icon {
    switch (type) {
      case 'booking':
        return Icons.confirmation_num_outlined;
      case 'reminder':
        return Icons.alarm_outlined;
      case 'social':
        return Icons.people_outline;
      case 'payment':
        return Icons.payment_outlined;
      case 'event_completed':
        return Icons.event_available_outlined;
      case 'review':
        return Icons.star_outline;
      case 'circle_added':
      case 'circle_join_request':
      case 'circle_approved':
      case 'circle_rejected':
      case 'circle_removed':
        return Icons.group_outlined;
      case 'dm':
      case 'message':
        return Icons.chat_bubble_outline;
      case 'admin_verification':
        return Icons.admin_panel_settings_outlined;
      case 'verification':
        return Icons.verified_user_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get iconColor {
    switch (type) {
      case 'booking':
        return Colors.green;
      case 'reminder':
        return Colors.amber;
      case 'social':
        return Colors.blue;
      case 'payment':
        return Colors.purple;
      case 'event_completed':
        return Colors.orange;
      case 'review':
        return Colors.amber;
      case 'circle_added':
      case 'circle_join_request':
      case 'circle_approved':
      case 'circle_rejected':
      case 'circle_removed':
        return Colors.blue;
      case 'dm':
      case 'message':
        return Colors.teal;
      case 'admin_verification':
        return Colors.orange;
      case 'verification':
        return Colors.green;
      default:
        return TheyDiColors.primary;
    }
  }
}

final _notificationsProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList());
});

/// Real-time stream of unread notification count for the current user.
final unreadNotificationsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Automatically mark all as read when the screen is viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _markAllRead(uid);
      }
    });
  }

  Future<void> _markAllRead(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final unread = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _markAsRead(String uid, String notifId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId)
        .update({'isRead': true});
  }

  Future<void> _clearAll(String uid) async {
    final docs = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final notificationsAsync = ref.watch(_notificationsProvider);

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
                    Text('Notifications',
                        style: TheyDiTextStyles.displayMedium),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: TheyDiColors.textSecondary),
                      color: TheyDiColors.card,
                      onSelected: (value) async {
                        if (value == 'read') {
                          await _markAllRead(uid);
                        } else if (value == 'clear') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: TheyDiColors.card,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: Text('Clear all?',
                                  style: TheyDiTextStyles.headlineMedium),
                              content: Text(
                                  'This will delete all notifications.',
                                  style: TheyDiTextStyles.bodyMedium.copyWith(
                                      color: TheyDiColors.textSecondary)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('Cancel',
                                      style: TheyDiTextStyles.labelMedium
                                          .copyWith(
                                              color:
                                                  TheyDiColors.textSecondary)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('Clear',
                                      style: TheyDiTextStyles.labelMedium
                                          .copyWith(color: TheyDiColors.error)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) await _clearAll(uid);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'read',
                          child: Row(children: [
                            Icon(Icons.done_all,
                                size: 18, color: TheyDiColors.textSecondary),
                            const SizedBox(width: 8),
                            Text('Mark all as read',
                                style: TheyDiTextStyles.bodySmall),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'clear',
                          child: Row(children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: TheyDiColors.error),
                            const SizedBox(width: 8),
                            Text('Clear all',
                                style: TheyDiTextStyles.bodySmall
                                    .copyWith(color: TheyDiColors.error)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 8),

              Expanded(
                child: notificationsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: TheyDiColors.primary)),
                  error: (e, _) => Center(
                      child: Text('Failed to load: $e',
                          style: TheyDiTextStyles.bodySmall)),
                  data: (notifications) {
                    if (notifications.isEmpty) {
                      return Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.notifications_none,
                              size: 64, color: Colors.grey[700]),
                          const SizedBox(height: 16),
                          Text('No notifications yet',
                              style: TheyDiTextStyles.headlineMedium),
                          const SizedBox(height: 8),
                          Text('You\'ll see booking updates and reminders here',
                              style: TheyDiTextStyles.bodySmall
                                  .copyWith(color: TheyDiColors.textSecondary),
                              textAlign: TextAlign.center),
                        ]),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        return _NotificationCard(
                          notification: notif,
                          myUid: uid,
                          onTap: (cardContext) async {
                            // Mark as read first (fire-and-forget, don't await before nav)
                            if (!notif.isRead) _markAsRead(uid, notif.id);
                            if (cardContext.mounted) {
                              await _handleNavigation(cardContext, notif);
                            }
                          },
                        )
                            .animate(delay: Duration(milliseconds: 50 * index))
                            .fade(duration: 300.ms)
                            .slideX(begin: 0.05, end: 0);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // NAVIGATION HANDLER — 12-case mapping
  //
  //  1.  event_completed           → My Events › Past › All
  //  2.  review (social/review)    → My Reviews screen
  //  3.  booking new               → Host Manage screen
  //  4.  booking complete payment  → Event Detail page
  //  5.  booking approved (user)   → My Events › Attending › attendees
  //  6.  booking join request      → Host Manage screen
  //  7.  booking spot cancelled    → Host Manage screen
  //  8.  dm (1:1 message)          → DM chat screen
  //  9.  dm circle message         → Circle chat screen (circles list fallback)
  //  10. social accepted           → Friends Hub › Connected tab
  //  11. social friend request     → Friends Hub › Pending tab
  //  12. circle_added / circle_*   → Circles list → Circle Info
  // ─────────────────────────────────────────────────────────
  Future<void> _handleNavigation(
      BuildContext context, NotificationModel notif) async {
    final t = notif.title.toLowerCase();
    final b = notif.body.toLowerCase();

    Future<void> openEventDetail() async {
      if (notif.eventId != null) {
        await _pushEventDetail(context, notif.eventId!);
      }
    }

    void goManageEvent() {
      if (notif.eventId != null) {
        context.push(AppRoutes.hostManage, extra: notif.eventId);
      }
    }

    switch (notif.type) {
      case 'system':
        if (t.contains('completed') || t.contains('ended')) {
          if (b.contains('marked as completed') ||
              t.contains('event completed')) {
            goManageEvent(); // Host
          } else {
            context.go(AppRoutes.myEvents,
                extra: {'tab': 2, 'filter': 'All'}); // Attendee
          }
        } else if (t.contains('created') || t.contains('live')) {
          goManageEvent();
        } else if (t.contains('cancelled') || t.contains('declined')) {
          context.go(AppRoutes.myEvents, extra: {'tab': 0, 'filter': 'All'});
        } else {
          await openEventDetail();
        }
        break;

      case 'payment':
        if (t.contains('payout')) {
          context.push(AppRoutes.hostDashboard);
        } else if (t.contains('new attendee') ||
            t.contains('new booking') ||
            b.contains('booked') ||
            b.contains('joined')) {
          goManageEvent();
        } else {
          context.push(AppRoutes.paymenthistory);
        }
        break;

      case 'booking':
        if (t.contains('you\'re in') ||
            (t.contains('approved') && !t.contains('join request'))) {
          context.go(AppRoutes.myEvents, extra: {'tab': 0, 'filter': 'All'});
        } else if (t.contains('join request') || t.contains('spot cancelled')) {
          goManageEvent();
        } else {
          await openEventDetail();
        }
        break;

      case 'suggested_event':
      case 'reminder':
        await openEventDetail();
        break;

      // ── 1. Event ended ──────────────────────────────────────────────────────

      case 'review':
        context.push(AppRoutes.myReviews);
        break;

// ── 3–7. Booking-type notifications ────────────────────────────────────
      case 'booking':
        final isCompletePayment =
            t.contains('complete payment') || b.contains('tap to pay');
        final isApproved = t.contains('approved') &&
            !t.contains('join request') &&
            !isCompletePayment;
        final isJoinRequest = t.contains('join request');
        final isNewBooking = t.contains('booking') || b.contains('booked');
        final isCancelled =
            t.contains('cancelled') || t.contains('spot cancelled');

        if (isCompletePayment && notif.eventId != null) {
          await _pushEventDetail(context, notif.eventId!);
        } else if (isApproved) {
          context.go(AppRoutes.myEvents, extra: {'tab': 0, 'filter': 'All'});
        } else if (isJoinRequest && notif.eventId != null) {
          context.push(AppRoutes.hostManage, extra: notif.eventId);
        } else if ((isNewBooking || isCancelled) && notif.eventId != null) {
          context.push(AppRoutes.hostManage, extra: notif.eventId);
        } else if (notif.eventId != null) {
          await _pushEventDetail(context, notif.eventId!);
        }

// ── Payment confirmed → Payment History ────────────────────────────────
      case 'payment':
        context.push(AppRoutes.paymenthistory);

// ── 8 & 9. Messages (DM or Circle) ─────────────────────────────────────
      case 'dm':
      case 'message':
        if (notif.circleId != null) {
          context.push(AppRoutes.circles);
        } else if (notif.fromUid != null) {
          final senderName = _extractSenderName(notif.title);
          context.push(AppRoutes.dmChat, extra: {
            'otherUid': notif.fromUid!,
            'otherName': senderName,
          });
        } else {
          context.push(AppRoutes.circles);
        }
        break;

      case 'social':
        final isAccepted = t.contains('accepted');
        final isFriendRequest = t.contains('friend request') && !isAccepted;
        final isAddedToCircle =
            t.contains('added to a circle') || t.contains('added you to');
        final isReview = t.contains('review');

        if (isReview) {
          // Review received → My Reviews
          context.push(AppRoutes.myReviews);
        } else if (isAddedToCircle) {
          // Added to circle → Circles list
          context.push(AppRoutes.circles);
        } else if (isAccepted && notif.fromUid != null) {
          context.push(AppRoutes.friendsHub);
        } else if (t.contains('friend request')) {
          context.push(AppRoutes.friendRequests);
        } else if (notif.type == 'suggested_friends') {
          context.push(
            AppRoutes.friendsHub,
            extra: {'initialTab': 2},
          );
        } else if (notif.fromUid != null) {
          context.push(AppRoutes.userProfile, extra: {
            'uid': notif.fromUid!,
            'requestId': null,
          });
        }
        break;

      case 'suggested_friends':
        context.push(AppRoutes.circleDiscovery);
        break;

      case 'suggested_circles':
      case 'circle_added':
      case 'circle_join_request':
      case 'circle_approved':
      case 'circle_rejected':
      case 'circle_removed':
        context.push(AppRoutes.circles);
        break;

      case 'admin_verification':
        context.push(AppRoutes.adminVerification);

      case 'verification':
        context.go(AppRoutes.profile);

      default:
        if (notif.eventId != null) {
          await openEventDetail();
        }
        break;
    }
  }

  /// Fetch event from Firestore and push event detail, or show fallback snackbar
  Future<void> _pushEventDetail(BuildContext context, String eventId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      if (!context.mounted) return;
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event no longer available'),
            backgroundColor: Colors.grey,
          ),
        );
        return;
      }
      final event = EventModel.fromFirestore(doc);
      context.push('/event/$eventId', extra: event);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open event'),
              backgroundColor: Colors.grey),
        );
      }
    }
  }

  String _extractSenderName(String title) {
    // "New message from Swetha 💬" → "Swetha"
    final match = RegExp(r'from (.+?)(?:\s*[^\w\s].*)?$').firstMatch(title);
    return match?.group(1)?.trim() ?? 'User';
  }
}

// ─────────────────────────────────────────────────────────
// NOTIFICATION CARD
// ─────────────────────────────────────────────────────────
class _NotificationCard extends StatefulWidget {
  final NotificationModel notification;
  final String myUid;
  final Function(BuildContext cardContext) onTap;

  const _NotificationCard({
    required this.notification,
    required this.myUid,
    required this.onTap,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _responded = false;
  bool _processing = false;
  bool _pressed = false;
  bool _loadingStatus = true;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _checkRequestStatus();
  }

  @override
  void didUpdateWidget(_NotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notification.id != widget.notification.id ||
        oldWidget.notification.fromUid != widget.notification.fromUid) {
      _checkRequestStatus();
    }
  }

  Future<void> _checkRequestStatus() async {
    final notif = widget.notification;
    final isFriendRequest = notif.type == 'social' &&
        notif.title.toLowerCase().contains('friend request') &&
        !notif.title.toLowerCase().contains('accepted');

    if (isFriendRequest && notif.fromUid != null) {
      setState(() => _loadingStatus = true);
      final requestId = await _findRequestId(notif.fromUid!);
      if (mounted) {
        setState(() {
          _responded = (requestId == null);
          _loadingStatus = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _loadingStatus = false;
        });
      }
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Future<String?> _findRequestId(String fromUid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.myUid)
        .collection('friendRequests')
        .where('fromUid', isEqualTo: fromUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.id;
    return null;
  }

  Future<void> _accept(String fromUid, String fromName) async {
    setState(() => _processing = true);
    final requestId = await _findRequestId(fromUid);
    if (requestId == null) {
      if (mounted) {
        setState(() {
          _processing = false;
          _responded = true;
        });
      }
      return;
    }
    await FriendsService.acceptFriendRequest(
        requestId: requestId, fromUid: fromUid, fromName: fromName);
    if (mounted) {
      setState(() {
        _responded = true;
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('You and $fromName are now friends! 🎉'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _decline(String fromUid) async {
    setState(() => _processing = true);
    final requestId = await _findRequestId(fromUid);
    if (requestId == null) {
      if (mounted) {
        setState(() {
          _processing = false;
          _responded = true;
        });
      }
      return;
    }
    await FriendsService.declineFriendRequest(
        requestId: requestId, myUid: widget.myUid);
    if (mounted) {
      setState(() {
        _responded = true;
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Request declined'), backgroundColor: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.notification;
    final isFriendRequest = notif.type == 'social' &&
        notif.title.toLowerCase().contains('friend request') &&
        !notif.title.toLowerCase().contains('accepted');

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () async {
        if (_navigating) return;
        _navigating = true;
        await widget.onTap(context);
        if (mounted) _navigating = false;
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _pressed
                ? TheyDiColors.card.withValues(alpha: 0.6)
                : notif.isRead
                    ? TheyDiColors.card
                    : TheyDiColors.card.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: notif.isRead
                  ? TheyDiColors.divider
                  : notif.iconColor.withValues(alpha: 0.35),
              width: notif.isRead ? 1 : 1.5,
            ),
            boxShadow: notif.isRead
                ? null
                : [
                    BoxShadow(
                        color: notif.iconColor.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: notif.iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(notif.icon, color: notif.iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(notif.title,
                                style: TheyDiTextStyles.labelMedium.copyWith(
                                    fontWeight: notif.isRead
                                        ? FontWeight.normal
                                        : FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (!notif.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: TheyDiColors.primary),
                            ),
                        ]),
                        const SizedBox(height: 3),
                        Text(notif.body,
                            style:
                                TheyDiTextStyles.caption.copyWith(height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),

                        // Navigation hint chip
                        Row(children: [
                          Text(_timeAgo(notif.createdAt),
                              style: TheyDiTextStyles.caption.copyWith(
                                  color: TheyDiColors.textMuted, fontSize: 11)),
                          const SizedBox(width: 8),
                          _NavHint(
                              type: notif.type,
                              title: notif.title,
                              body: notif.body),
                        ]),
                      ],
                    ),
                  ),

                  // Chevron
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 18,
                      color: TheyDiColors.textMuted.withValues(alpha: 0.5)),
                ],
              ),

              // ── Friend request inline action buttons ──
              if (isFriendRequest &&
                  notif.fromUid != null &&
                  !_loadingStatus &&
                  !_responded) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _processing ? null : () => _decline(notif.fromUid!),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: TheyDiColors.divider),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text('Decline',
                          style: TheyDiTextStyles.labelMedium
                              .copyWith(color: TheyDiColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(10)),
                      child: ElevatedButton(
                        onPressed: _processing
                            ? null
                            : () {
                                final senderName = notif.body.split(' ').first;
                                _accept(notif.fromUid!, senderName);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: _processing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Accept',
                                style: TheyDiTextStyles.labelMedium
                                    .copyWith(color: Colors.white)),
                      ),
                    ),
                  ),
                ]),
              ],

              if (isFriendRequest && !_loadingStatus && _responded)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Responded',
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textMuted)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small navigation hint chip shown inside the card ──
class _NavHint extends StatelessWidget {
  final String type;
  final String title;
  final String body;
  const _NavHint({required this.type, required this.title, required this.body});

  String get _hint {
    final t = title.toLowerCase();
    final b = body.toLowerCase();
    switch (type) {
      case 'system':
        if (t.contains('completed') || t.contains('ended')) {
          return b.contains('marked as completed')
              ? 'Manage Event'
              : 'Past Events';
        }
        if (t.contains('created') || t.contains('live')) return 'Manage Event';
        if (t.contains('cancelled')) return 'My Events';
        return 'Open Event';
      case 'review':
        return 'My Reviews';
      case 'booking':
        if (t.contains('complete payment') || b.contains('tap to pay')) {
          return 'Open Event';
        }

        if (t.contains("you're in") ||
            (t.contains('approved') && !t.contains('join request'))) {
          return 'My Events';
        }

        if (t.contains('join request') ||
            t.contains('spot cancelled') ||
            t.contains('booking')) {
          return 'Manage Event';
        }

        return 'Open Event';
      case 'payment':
        if (t.contains('payout')) return 'Host Dashboard';
        if (t.contains('new attendee') ||
            t.contains('new booking') ||
            b.contains('booked')) {
          return 'Manage Event';
        }
        return 'Payment History';
      case 'dm':
      case 'message':
        return 'Open Chat';
      case 'social':
        if (t.contains('accepted')) return 'Friends';
        if (t.contains('added to a circle') || t.contains('added you to')) {
          return 'Circles';
        }
        return 'Friend Requests';
      case 'suggested_friends':
        return 'Discover Friends';
      case 'suggested_circles':
      case 'circle_added':
      case 'circle_join_request':
      case 'circle_approved':
      case 'circle_rejected':
      case 'circle_removed':
        return 'Circles';
      case 'reminder':
      case 'suggested_event':
        return 'Open Event';
      case 'admin_verification':
        return 'View Requests';
      case 'verification':
        return 'View Status';
      default:
        if (t.contains('review')) return 'My Reviews';
        return 'View';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: TheyDiColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TheyDiColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.arrow_forward, size: 9, color: TheyDiColors.primary),
        const SizedBox(width: 3),
        Text(_hint,
            style: TheyDiTextStyles.caption.copyWith(
                color: TheyDiColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Reusable badge for the Home screen notification bell.
/// Wrap your notification icon with this widget.
class NotificationBadge extends ConsumerWidget {
  final Widget child;
  const NotificationBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadNotificationsCountProvider);

    return countAsync.maybeWhen(
      data: (count) {
        if (count == 0) return child;
        final label = count > 99 ? '99+' : '$count';

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TheyDiColors.card, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      orElse: () => child,
    );
  }
}
