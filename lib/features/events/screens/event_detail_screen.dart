import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../models/event_model.dart';
import '../../../core/services/notification_service.dart';
import 'package:theydi/features/events/widgets/event_share_sheet.dart';

// ─────────────────────────────────────────────────────────────
// State machine:
//   Free + FirstCome:        none → joined
//   Free + HostApproval:     none → pending → joined
//   Paid + FirstCome:        none → [payment] → joined
//   Paid + HostApproval:     none → pending → approvedAwaitPay → [payment] → joined
// ─────────────────────────────────────────────────────────────
enum _BookingState { none, pending, approvedAwaitPay, joined, rejected }

class EventDetailScreen extends ConsumerStatefulWidget {
  final EventModel event;
  const EventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _isProcessing = false;
  late EventModel _event;

  String _eventType = '';
  int _durationHours = 0;
  String _ageGroup = '';
  String _genderBalance = '';
  String _approvalType = '';
  Map<String, dynamic>? _genderRatio;
  bool _hostVerified = false;
  bool _extraLoaded = false;
  int _userAge = 99;   // current user's age
  int _minAge = 0;     // event min age (18 for Adult Party)

  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  bool _shareAnimating = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadExtraFields();
    // Live-listen so state updates instantly when host approves
    FirebaseFirestore.instance
        .collection('events')
        .doc(widget.event.id)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() => _event = EventModel.fromFirestore(doc));
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadExtraFields() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _eventType = data['eventType'] ?? '';
          _durationHours = data['durationHours'] ?? 0;
          _ageGroup = data['ageGroup'] ?? '';
          _genderBalance = data['genderBalance'] ?? '';
          _approvalType = data['approvalType'] ?? '';
          _genderRatio = data['genderRatio'] as Map<String, dynamic>?;
          _minAge = (data['minAge'] as num?)?.toInt() ?? 0;
          _extraLoaded = true;
        });
      }
      final hostDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.event.creatorUid)
          .get();
      if (hostDoc.exists) {
        setState(() => _hostVerified = hostDoc.data()?['isVerified'] ?? true);
      }
      // Load current user's age for 18+ check
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final dob = userDoc.data()?['dob'];
          DateTime? birthDate;
          if (dob is Timestamp) birthDate = dob.toDate();
          else if (dob is String && dob.isNotEmpty) birthDate = DateTime.tryParse(dob);
          if (birthDate != null) {
            final today = DateTime.now();
            int age = today.year - birthDate.year;
            if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) age--;
            if (mounted) setState(() => _userAge = age);
          }
        }
      }
    } catch (_) {
      setState(() => _extraLoaded = true);
    }
  }

  // ── Derive booking state from live Firestore data ──
  _BookingState get _bookingState {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _BookingState.none;
    if (_event.attendeeUids.contains(uid)) return _BookingState.joined;
    if (_event.approvedPendingPaymentUids.contains(uid)) return _BookingState.approvedAwaitPay;
    if (_event.pendingUids.contains(uid)) return _BookingState.pending;
    return _BookingState.none;
  }

  bool get _isHost => FirebaseAuth.instance.currentUser?.uid == widget.event.creatorUid;
  bool get _isPastEvent => _event.endTime.isBefore(DateTime.now());

  // ── Navigate to host profile ─────────────────────────────────────────────────
  // ADDED: skip navigation if viewer is the host themselves
  void _viewHostProfile() {
    if (_isHost) return;
    context.push(AppRoutes.userProfile,
        extra: {'uid': widget.event.creatorUid, 'requestId': null});
  }

  // ── Main action dispatcher ──
  Future<void> _handleAction() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _isProcessing) return;
    switch (_bookingState) {
      case _BookingState.none:           await _joinEvent(uid);
      case _BookingState.pending:        await _cancelRequest(uid);
      case _BookingState.approvedAwaitPay:
        if (mounted) context.push(AppRoutes.payment, extra: {'event': _event, 'fromApproval': true});

      // ── CHANGED: joined → navigate to attendees screen ──
      case _BookingState.joined:
        if (mounted) context.push(AppRoutes.eventAttendees, extra: _event);

      case _BookingState.rejected:       break;
    }
  }

  Future<void> _joinEvent(String uid) async {
    // 18+ check for Adult Party
    if (_event.category == 'Adult Party' || _minAge >= 18) {
      if (_userAge < 18) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔞 This event is for 18+ only. You must be 18 or older to join.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      // DOB not set
      if (_userAge == 99) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔞 Please update your date of birth in your profile to join this 18+ event.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }
    setState(() => _isProcessing = true);
    try {
      final eventRef = FirebaseFirestore.instance.collection('events').doc(_event.id);
      String userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Someone';
      try {
        final d = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (d.exists) userName = d.data()?['displayName'] ?? userName;
      } catch (_) {}

      final isFree = _event.isFree;
      final isHostApproval = _approvalType == 'Host Approval';

      if (isFree && !isHostApproval) {
        // Free + First Come → join directly
        await eventRef.update({'attendeeUids': FieldValue.arrayUnion([uid])});
        await FirebaseFirestore.instance.collection('users').doc(uid)
            .update({'eventsAttended': FieldValue.increment(1)});
        await NotificationService.notifyFreeEventJoined(
            userUid: uid, eventTitle: _event.title, eventId: _event.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You\'re in! 🎉'), backgroundColor: Colors.green));

      } else if (isFree && isHostApproval) {
        // Free + Host Approval → request
        await eventRef.update({'pendingUids': FieldValue.arrayUnion([uid])});
        await NotificationService.notifyJoinRequest(
            hostUid: _event.creatorUid, requesterName: userName,
            eventTitle: _event.title, eventId: _event.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request sent! The host will review it 📩'), backgroundColor: Colors.green));

      } else if (!isFree && !isHostApproval) {
        // Paid + First Come → straight to payment
        if (mounted) context.push(AppRoutes.payment, extra: {'event': _event, 'fromApproval': false});

      } else {
        // Paid + Host Approval → request first, payment after approval
        await eventRef.update({'pendingUids': FieldValue.arrayUnion([uid])});
        await NotificationService.notifyJoinRequest(
            hostUid: _event.creatorUid, requesterName: userName,
            eventTitle: _event.title, eventId: _event.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request sent! You\'ll be notified to pay after approval 📩'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _cancelRequest(String uid) async {
    final ok = await _confirmCancel(
        title: 'Cancel Request?',
        message: 'Are you sure you want to cancel your join request for "${_event.title}"?');
    if (!ok) return;
    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance.collection('events').doc(_event.id)
          .update({'pendingUids': FieldValue.arrayRemove([uid])});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled'), backgroundColor: Colors.grey));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<bool> _confirmCancel({required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TheyDiTextStyles.headlineMedium),
        content: Text(message,
            style: TheyDiTextStyles.bodyMedium.copyWith(color: TheyDiColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No, Keep',
                style: TheyDiTextStyles.labelMedium.copyWith(color: TheyDiColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, Cancel',
                style: TheyDiTextStyles.labelMedium.copyWith(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildShareButton() {
    return GestureDetector(
      onTap: () async {
        setState(() => _shareAnimating = true);
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) setState(() => _shareAnimating = false);
        if (mounted) showEventShareSheet(context, event: _event);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
      )
          .animate(target: _shareAnimating ? 1 : 0)
          .scale(begin: const Offset(1, 1), end: const Offset(1.25, 1.25), duration: 150.ms, curve: Curves.easeOut)
          .then()
          .scale(begin: const Offset(1.25, 1.25), end: const Offset(1, 1), duration: 150.ms),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    // Past event
    if (_isPastEvent) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (_event.attendeeUids.contains(uid) && !_isHost) {
        return SizedBox(
          width: double.infinity, height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [Color(0xFFFF4466), Color(0xFFAA44FF)])),
            child: ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.submitReview, extra: widget.event),
              icon: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
              label: const Text('Leave a Review',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ),
        );
      }
      if (_isHost) {
        return SizedBox(
          width: double.infinity, height: 54,
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.hostDashboard),
            icon: Icon(Icons.analytics_outlined, color: TheyDiColors.textSecondary, size: 20),
            label: Text('View Dashboard',
                style: TheyDiTextStyles.labelLarge.copyWith(color: TheyDiColors.textSecondary)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: TheyDiColors.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // Active event — derive label and style
    final state = _bookingState;
    final isFull = _event.isFull && state == _BookingState.none;

    String label;
    bool isOutlined = false;
    Color? outlineColor;
    bool disabled = isFull;

    switch (state) {
      case _BookingState.none:
        if (isFull) { label = 'Event Full'; }
        else if (_event.isFree && _approvalType == 'Host Approval') { label = 'Request to Join'; }
        else if (_event.isFree) { label = 'Join Now — Free'; }
        else if (_approvalType == 'Host Approval') { label = 'Request to Join'; }
        else { label = 'Join for ₹${_event.price.toInt()}'; }

      case _BookingState.pending:
        label = '⏳ Request Pending — Tap to Cancel';
        isOutlined = true; outlineColor = Colors.amber;

      case _BookingState.approvedAwaitPay:
        label = '✓ Joined — Tap to Pay ₹${_event.price.toInt()}';

      case _BookingState.joined:
        label = '✓ Joined — Tap to View';

      case _BookingState.rejected:
        label = 'Request Rejected';
        isOutlined = true; outlineColor = Colors.red; disabled = true;
    }

    if (_isProcessing) label = 'Please wait...';

    if (isOutlined) {
      return SizedBox(
        width: double.infinity, height: 54,
        child: OutlinedButton(
          onPressed: (_isProcessing || disabled) ? null : _handleAction,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: outlineColor ?? TheyDiColors.divider, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isProcessing
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: TheyDiTextStyles.labelLarge.copyWith(color: outlineColor ?? TheyDiColors.textSecondary)),
        ),
      );
    }

    return GradientButton(
      label: label,
      onPressed: (_isProcessing || disabled) ? () {} : _handleAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(event.dateTime);
    final timeStr = DateFormat('h:mm a').format(event.dateTime);
    final images = event.allImages;
    final hasImages = images.isNotEmpty;
    final showPayBanner = _bookingState == _BookingState.approvedAwaitPay;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [TheyDiColors.cardLight, TheyDiColors.surface],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: CustomScrollView(slivers: [
          // ── Hero Banner ──
          SliverAppBar(
            expandedHeight: 240, pinned: true,
            backgroundColor: TheyDiColors.dark,
            actions: [_buildShareButton()],
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: hasImages
                  ? _ImageCarousel(
                      images: images, currentIndex: _currentImageIndex,
                      pageController: _pageController,
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      event: event)
                  : _GradientBanner(event: event),
            ),
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Payment-approved banner
                if (showPayBanner) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Your request was approved! 🎉',
                            style: TheyDiTextStyles.labelMedium.copyWith(color: Colors.blue)),
                        const SizedBox(height: 2),
                        Text('Complete payment below to confirm your spot.',
                            style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textSecondary)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // Tag Pills
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _TagPill(label: event.category, icon: Icons.category_outlined),
                  if (_ageGroup.isNotEmpty) _TagPill(label: _ageGroup, icon: Icons.people_alt_outlined),
                  if (_eventType.isNotEmpty) _TagPill(
                      label: _eventType,
                      icon: _eventType == 'Indoor' ? Icons.home_outlined : Icons.park_outlined),
                  if (_event.category == 'Adult Party' || _minAge >= 18) _TagPill(
                      label: '🔞 18+ Only',
                      icon: Icons.no_adult_content,
                      color: Colors.red),
                ]).animate().fade(duration: 300.ms),

                const SizedBox(height: 16),

                Text(event.title, style: TheyDiTextStyles.displayMedium)
                    .animate(delay: 50.ms).fade(duration: 300.ms),
                const SizedBox(height: 8),
                Row(children: [
                  Text(
                    event.isFull ? 'FULL' : '${event.spotsLeft} spots left',
                    style: TheyDiTextStyles.labelMedium.copyWith(
                        color: event.isFull ? TheyDiColors.error
                            : event.spotsLeft < 5 ? TheyDiColors.error
                            : TheyDiColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text('·', style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textMuted)),
                  const SizedBox(width: 8),
                  Text('${event.currentAttendees} going',
                      style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textSecondary)),
                  if (_approvalType.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text('·', style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textMuted)),
                    const SizedBox(width: 8),
                    Icon(
                        _approvalType == 'Host Approval'
                            ? Icons.verified_user_outlined
                            : Icons.flash_on_outlined,
                        size: 14, color: TheyDiColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                        _approvalType == 'Host Approval' ? 'Approval needed' : 'First come',
                        style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textMuted)),
                  ],
                ]).animate(delay: 70.ms).fade(duration: 300.ms),

                const SizedBox(height: 20),

                Text('About this event', style: TheyDiTextStyles.displayLarge)
                    .animate(delay: 90.ms).fade(duration: 300.ms),
                const SizedBox(height: 8),
                Text(event.description,
                    style: TheyDiTextStyles.bodyMedium.copyWith(
                        color: TheyDiColors.textSecondary, height: 1.6))
                    .animate(delay: 110.ms).fade(duration: 300.ms),

                const SizedBox(height: 20),

                Row(children: [
                  Expanded(child: _InfoCard(icon: Icons.calendar_today_outlined, title: 'Date', value: dateStr)),
                  const SizedBox(width: 12),
                  Expanded(child: _InfoCard(icon: Icons.access_time_outlined, title: 'Time', value: timeStr)),
                ]).animate(delay: 120.ms).fade(duration: 300.ms),
                const SizedBox(height: 12),
                if (_durationHours > 0) ...[
                  _InfoCard(icon: Icons.timer_outlined, title: 'Duration',
                      value: '$_durationHours hour${_durationHours > 1 ? 's' : ''}', fullWidth: true)
                      .animate(delay: 130.ms).fade(duration: 300.ms),
                  const SizedBox(height: 12),
                ],
                if (_ageGroup.isNotEmpty) ...[
                  _InfoCard(icon: Icons.people_outline, title: 'Age Group', value: _ageGroup, fullWidth: true)
                      .animate(delay: 140.ms).fade(duration: 300.ms),
                  const SizedBox(height: 12),
                ],
                _InfoCard(icon: Icons.location_on_outlined, title: 'Location',
                    value: '${event.venue}, ${event.city}', fullWidth: true)
                    .animate(delay: 150.ms).fade(duration: 300.ms),
                if (_eventType.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoCard(
                      icon: _eventType == 'Indoor' ? Icons.home_outlined : Icons.park_outlined,
                      title: 'Venue Type', value: _eventType, fullWidth: true)
                      .animate(delay: 160.ms).fade(duration: 300.ms),
                ],

                const SizedBox(height: 20),

                // ── Host card — avatar + name tappable → profile ──
                // ADDED: MouseRegion + GestureDetector on avatar+name, skip if own event
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: TheyDiColors.card, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TheyDiColors.divider)),
                  child: Row(children: [
                    MouseRegion(
                      cursor: _isHost
                          ? SystemMouseCursors.basic
                          : SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _isHost ? null : _viewHostProfile,
                        child: Row(children: [
                          // Avatar
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                                gradient: TheyDiColors.gradientPrimary,
                                borderRadius: BorderRadius.circular(14)),
                            child: Center(child: Text(
                                event.organizerName.isNotEmpty ? event.organizerName[0].toUpperCase() : '?',
                                style: TheyDiTextStyles.displayLarge.copyWith(color: Colors.white, fontSize: 22))),
                          ),
                          const SizedBox(width: 12),
                          // Name + verified badge + open_in_new hint
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Organised by', style: TheyDiTextStyles.caption),
                            const SizedBox(height: 2),
                            Row(children: [
                              Text(event.organizerName, style: TheyDiTextStyles.labelLarge),
                              if (_hostVerified) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: TheyDiColors.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.verified, size: 12, color: TheyDiColors.warning),
                                    const SizedBox(width: 3),
                                    Text('Verified', style: TheyDiTextStyles.caption.copyWith(
                                        color: TheyDiColors.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              ],
                              // Hint icon — only shown to non-host viewers
                              if (!_isHost) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.open_in_new,
                                    size: 13, color: TheyDiColors.textMuted),
                              ],
                            ]),
                          ]),
                        ]),
                      ),
                    ),
                  ]),
                ).animate(delay: 200.ms).fade(duration: 300.ms),

                const SizedBox(height: 20),

                if (_extraLoaded)
                  _EventDetailsSection(
                      genderBalance: _genderBalance, genderRatio: _genderRatio,
                      ageGroup: _ageGroup, approvalType: _approvalType,
                      maxAttendees: event.maxAttendees,
                      currentAttendees: event.currentAttendees)
                      .animate(delay: 320.ms).fade(duration: 300.ms),

                const SizedBox(height: 20),

                if (event.tags.isNotEmpty) ...[
                  Text('Tags', style: TheyDiTextStyles.displayLarge)
                      .animate(delay: 350.ms).fade(duration: 300.ms),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: event.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: TheyDiColors.card, borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: TheyDiColors.divider)),
                      child: Text('#$tag', style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textSecondary)),
                    )).toList(),
                  ).animate(delay: 370.ms).fade(duration: 300.ms),
                  const SizedBox(height: 20),
                ],

                _SafetyTrustSection(hostVerified: _hostVerified)
                    .animate(delay: 400.ms).fade(duration: 300.ms),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
            color: TheyDiColors.dark,
            border: Border(top: BorderSide(color: TheyDiColors.divider))),
        child: _buildBottomButton(context),
      ),
    );
  }
}

// ── Image Carousel ──
class _ImageCarousel extends StatelessWidget {
  final List<String> images;
  final int currentIndex;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final EventModel event;

  const _ImageCarousel({
    required this.images, required this.currentIndex,
    required this.pageController, required this.onPageChanged,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      PageView.builder(
        controller: pageController,
        onPageChanged: onPageChanged,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Image.network(images[index], fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _GradientBanner(event: event),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(color: TheyDiColors.dark, child: Center(
                child: CircularProgressIndicator(
                  color: TheyDiColors.primary,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                ),
              ));
            },
          );
        },
      ),
      Positioned(bottom: 16, right: 16, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: event.isFree ? Colors.green : Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20)),
        child: Text(event.isFree ? 'FREE' : '₹${event.price.toInt()}',
            style: TheyDiTextStyles.labelLarge.copyWith(color: Colors.white)),
      )),
      if (images.length > 1) ...[
        Positioned(bottom: 16, left: 0, right: 0, child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: currentIndex == i ? 20 : 6, height: 6,
            decoration: BoxDecoration(
              color: currentIndex == i ? Colors.white : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
            ),
          )),
        )),
        Positioned(top: 56, right: 12, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10)),
          child: Text('${currentIndex + 1}/${images.length}',
              style: TheyDiTextStyles.caption.copyWith(color: Colors.white, fontSize: 11)),
        )),
      ],
    ]);
  }
}

class _GradientBanner extends StatelessWidget {
  final EventModel event;
  const _GradientBanner({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: TheyDiColors.gradientPrimary),
      child: Stack(children: [
        Center(child: Text(event.category, style: TheyDiTextStyles.displayLarge
            .copyWith(color: Colors.white.withOpacity(0.2), fontSize: 64))),
        Positioned(bottom: 16, right: 16, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: event.isFree ? Colors.green : Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20)),
          child: Text(event.isFree ? 'FREE' : '₹${event.price.toInt()}',
              style: TheyDiTextStyles.labelLarge.copyWith(color: Colors.white)),
        )),
      ]),
    );
  }
}

// ── Helpers ──

class _TagPill extends StatelessWidget {
  final String label; final IconData icon; final Color? color;
  const _TagPill({required this.label, required this.icon, this.color});
  @override
  Widget build(BuildContext context) {
    final col = color ?? TheyDiColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: col), const SizedBox(width: 6),
        Text(label, style: TheyDiTextStyles.caption.copyWith(color: col, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon; final String title; final String value; final bool fullWidth;
  const _InfoCard({required this.icon, required this.title, required this.value, this.fullWidth = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: TheyDiColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: TheyDiColors.divider)),
    child: Row(children: [
      Icon(icon, color: TheyDiColors.primary, size: 18), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TheyDiTextStyles.caption),
        Text(value, style: TheyDiTextStyles.labelMedium, maxLines: fullWidth ? 2 : 1, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

class _EventDetailsSection extends StatelessWidget {
  final String genderBalance; final Map<String, dynamic>? genderRatio;
  final String ageGroup; final String approvalType;
  final int maxAttendees; final int currentAttendees;
  const _EventDetailsSection({required this.genderBalance, this.genderRatio, required this.ageGroup, required this.approvalType, required this.maxAttendees, required this.currentAttendees});

  @override
  Widget build(BuildContext context) {
    if (!genderBalance.isNotEmpty && !ageGroup.isNotEmpty && !approvalType.isNotEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Event details', style: TheyDiTextStyles.displayLarge),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: TheyDiColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: TheyDiColors.divider)),
        child: Column(children: [
          _DetailRow(icon: Icons.group_outlined, label: 'Capacity', value: '$currentAttendees / $maxAttendees attending'),
          if (genderBalance.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailRow(icon: Icons.people_outline, label: 'Gender', value: genderBalance),
            if (genderBalance == 'Ratio' && genderRatio != null) ...[
              const SizedBox(height: 8),
              Padding(padding: const EdgeInsets.only(left: 30), child: Column(children: [
                ClipRRect(borderRadius: BorderRadius.circular(4), child: Row(children: [
                  Expanded(flex: (genderRatio!['male'] ?? 50).toInt().clamp(1, 100), child: Container(height: 6, color: Colors.blue)),
                  Expanded(flex: (genderRatio!['female'] ?? 25).toInt().clamp(1, 100), child: Container(height: 6, color: Colors.pink)),
                  Expanded(flex: (genderRatio!['other'] ?? 25).toInt().clamp(1, 100), child: Container(height: 6, color: Colors.green)),
                ])),
                const SizedBox(height: 4),
                Row(children: [
                  _RatioLabel('Male ${(genderRatio!['male'] ?? 50).toInt()}%', Colors.blue),
                  const SizedBox(width: 10),
                  _RatioLabel('Female ${(genderRatio!['female'] ?? 25).toInt()}%', Colors.pink),
                  const SizedBox(width: 10),
                  _RatioLabel('Other ${(genderRatio!['other'] ?? 25).toInt()}%', Colors.green),
                ]),
              ])),
            ],
          ],
          if (ageGroup.isNotEmpty) ...[const SizedBox(height: 12), _DetailRow(icon: Icons.people_alt_outlined, label: 'Age group', value: ageGroup)],
          if (approvalType.isNotEmpty) ...[const SizedBox(height: 12), _DetailRow(icon: approvalType == 'Host Approval' ? Icons.verified_user_outlined : Icons.flash_on_outlined, label: 'Entry', value: approvalType)],
        ]),
      ),
    ]);
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: TheyDiColors.textMuted), const SizedBox(width: 10),
    Text('$label: ', style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textSecondary)),
    Expanded(child: Text(value, style: TheyDiTextStyles.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
  ]);
}

class _RatioLabel extends StatelessWidget {
  final String text; final Color color;
  const _RatioLabel(this.text, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    const SizedBox(width: 4),
    Text(text, style: TheyDiTextStyles.caption.copyWith(fontSize: 10)),
  ]);
}

class _SafetyTrustSection extends StatelessWidget {
  final bool hostVerified;
  const _SafetyTrustSection({required this.hostVerified});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.shield_outlined, size: 20, color: Colors.green), const SizedBox(width: 8), Text('Safety & Trust', style: TheyDiTextStyles.displayLarge)]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: TheyDiColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.green.withValues(alpha: 0.2))),
        child: Column(children: [
          _SafetyItem(icon: Icons.verified_user, text: hostVerified ? 'Host is verified' : 'Host verification pending', isActive: hostVerified),
          const SizedBox(height: 10), const _SafetyItem(icon: Icons.phone_android, text: 'Phone number verified', isActive: true),
          const SizedBox(height: 10), const _SafetyItem(icon: Icons.lock_outline, text: 'Secure booking system', isActive: true),
          const SizedBox(height: 10), const _SafetyItem(icon: Icons.gavel_outlined, text: 'Community guidelines enforced', isActive: true),
          const SizedBox(height: 10), const _SafetyItem(icon: Icons.support_agent, text: 'Support available', isActive: true),
        ]),
      ),
    ]);
  }
}

class _SafetyItem extends StatelessWidget {
  final IconData icon; final String text; final bool isActive;
  const _SafetyItem({required this.icon, required this.text, required this.isActive});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: isActive ? Colors.green : TheyDiColors.textMuted),
    const SizedBox(width: 10),
    Text(text, style: TheyDiTextStyles.bodySmall.copyWith(color: isActive ? TheyDiColors.textSecondary : TheyDiColors.textMuted)),
  ]);
}
