// ─────────────────────────────────────────────────────────────────────────────
// CHANGES vs original home_screen.dart
//
//  1. Added imports for ReviewTriggerService and ReviewPopup
//  2. initState: added _checkPendingReview() call after _loadUserLocation
//  3. Added _checkPendingReview() method — fetches pending event, shows popup
//     after a 1.5s delay (gives screen time to settle)
//  4. Everything else 100% unchanged
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/models/event_model.dart';
import '../../map/events_map_screen.dart';
import '../../../shared/widgets/notification_icon_button.dart';


// ── NEW imports ──
import '../../reviews/services/review_trigger_service.dart';
import '../../reviews/widgets/review_popup.dart';

import '../../support/screens/darla_chat_screen.dart';

final _userCityProvider = StreamProvider.autoDispose<String>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value('');
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => (doc.data()?['city'] as String?) ?? '');
});

final _allEventsProvider = StreamProvider.autoDispose<List<EventModel>>((ref) {
  final cutoff = DateTime.now().subtract(const Duration(days: 2));
  return FirebaseFirestore.instance
      .collection('events')
      .where('dateTime', isGreaterThan: Timestamp.fromDate(cutoff))
      .orderBy('dateTime')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .where((e) => !e.isCompleted)
          .toList());
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'All';
  String _selectedSort = 'Radius';
  double _selectedRadius = 2.0;
  bool _priceAscending = true;
  double? _userLat;
  double? _userLng;
  bool _locationLoading = true;

  final List<String> _categories = [
    'All',
    'Music',
    'Tech',
    'Sports',
    'Art',
    'Food',
    'Networking',
    'Gaming',
    'Fitness',
    'Comedy',
    'Workshop',
    'Party',
    'Social',
    'Adult Party',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    // ── NEW: check for post-event review popup ──
    _checkPendingReview();
  }

  // ── NEW: shows review popup if user has a completed unreviewed event ──
  Future<void> _checkPendingReview() async {
    // Wait for screen to settle before showing popup
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final pendingEvent = await ReviewTriggerService.getPendingReviewEvent();
    if (pendingEvent != null && mounted) {
      showReviewPopup(context, event: pendingEvent);
    }
  }

  Future<void> _loadUserLocation() async {
    // ---> TEMPORARY CODE TO GET TOKEN <---
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken(true);

    }
    // -------------------------------------

    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _userLat = position.latitude;
          _userLng = position.longitude;
          _locationLoading = false;
        });
      } else {
        if (mounted) setState(() => _locationLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  double _getEventDistance(EventModel event) {
    if (_userLat == null || _userLng == null) return -1;
    return LocationService.calculateDistanceKm(
      lat1: _userLat!,
      lon1: _userLng!,
      lat2: event.latitude,
      lon2: event.longitude,
    );
  }

  List<EventModel> _filterAndSortEvents(
      List<EventModel> events, String userCity) {
    List<EventModel> cityEvents = events;
    if (userCity.isNotEmpty) {
      cityEvents = events
          .where((e) => e.city.toLowerCase() == userCity.toLowerCase())
          .toList();
      if (cityEvents.isEmpty) cityEvents = events;
    }
    if (_selectedCategory != 'All') {
      cityEvents =
          cityEvents.where((e) => e.category == _selectedCategory).toList();
    }
    if (_selectedRadius > 0 && _userLat != null && _userLng != null) {
      var rf = cityEvents.where((e) {
        final d = _getEventDistance(e);
        return d >= 0 && d <= _selectedRadius;
      }).toList();
      if (rf.isEmpty) {
        for (final r in [2.0, 5.0, 10.0, 20.0, 50.0]) {
          if (r <= _selectedRadius) continue;
          rf = cityEvents.where((e) {
            final d = _getEventDistance(e);
            return d >= 0 && d <= r;
          }).toList();
          if (rf.isNotEmpty) break;
        }
        if (rf.isEmpty) rf = cityEvents;
      }
      cityEvents = rf;
    }
    switch (_selectedSort) {
      case 'Radius':
        if (_userLat != null && _userLng != null) {
          cityEvents.sort((a, b) {
            final dA = _getEventDistance(a), dB = _getEventDistance(b);
            if (dA < 0 && dB < 0) return 0;
            if (dA < 0) return 1;
            if (dB < 0) return -1;
            return dA.compareTo(dB);
          });
        }
      case 'Date':
        cityEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      case 'Price ₹':
        cityEvents.sort((a, b) => _priceAscending
            ? a.price.compareTo(b.price)
            : b.price.compareTo(a.price));
    }
    return cityEvents;
  }

  List<EventModel> _topEventsForLocation(
      List<EventModel> events, String userCity) {
    final locationEvents = userCity.isEmpty
        ? events.toList()
        : events
            .where((e) => e.city.toLowerCase() == userCity.toLowerCase())
            .toList();
    locationEvents.sort((a, b) {
      final attendeeCompare = b.currentAttendees.compareTo(a.currentAttendees);
      if (attendeeCompare != 0) return attendeeCompare;
      return a.dateTime.compareTo(b.dateTime);
    });
    return locationEvents.take(5).toList();
  }

  void _openMapView(List<EventModel> events) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => FadeTransition(
        opacity: anim,
        child: EventsMapScreen(
            events: events, userLat: _userLat, userLng: _userLng),
      ),
      transitionDuration: const Duration(milliseconds: 300),
    ));
  }

  void _showRadiusSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final maxWidth = math.min(size.width, 520.0);
        final maxHeight = size.height * 0.78;
        final options = LocationService.radiusOptions
            .where((o) => o['value'] != 50.0 && o['value'] != -1.0)
            .toList();

        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Text('Distance filter',
                        style: TheyDiTextStyles.displayMedium),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final isSelected = _selectedRadius == option['value'];
                          return GestureDetector(
                            onTap: () {
                              setState(() =>
                                  _selectedRadius = option['value'] as double);
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? TheyDiColors.primary
                                        .withValues(alpha: 0.15)
                                    : TheyDiColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isSelected
                                        ? TheyDiColors.primary
                                        : TheyDiColors.divider),
                              ),
                              child: Row(children: [
                                Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: isSelected
                                        ? TheyDiColors.primary
                                        : TheyDiColors.textMuted,
                                    size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(option['label'] as String,
                                      style: TheyDiTextStyles.labelMedium
                                          .copyWith(
                                              color: isSelected
                                                  ? TheyDiColors.primary
                                                  : TheyDiColors.textSecondary,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal)),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check,
                                      color: TheyDiColors.primary, size: 18),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String get _radiusLabel =>
      _selectedRadius < 0 ? 'Entire City' : '${_selectedRadius.toInt()} km';

  @override
  Widget build(BuildContext context) {
    final userCityAsync = ref.watch(_userCityProvider);
    final eventsAsync = ref.watch(_allEventsProvider);
    final userCity = userCityAsync.asData?.value ?? '';

    return Scaffold(
      floatingActionButton: GestureDetector(
    onTap: () {
      GoRouter.of(rootNavigatorKey.currentContext!).push(AppRoutes.darlaChat);
    },
    child: Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        gradient: TheyDiColors.gradientPrimary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: TheyDiColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.support_agent_rounded,
        color: Colors.white,
        size: 30,
      ),
    ),
  ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── TOP BAR ──
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Container(
  padding: EdgeInsets.zero,
  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: TheyDiColors.primary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text('T',
                                              style: TheyDiTextStyles
                                                  .headlineSmall
                                                  .copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w900)),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
  'Hey there 👋',
  style: TheyDiTextStyles.headlineSmall.copyWith(
    fontWeight: FontWeight.w700,
  ),
),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                NotificationIconButton(
                                  borderColor: const Color.fromARGB(255, 229, 235, 229),
                                  iconColor: const Color.fromARGB(255, 75, 85, 99),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () =>
                                      context.push(AppRoutes.friendsHub),
                                  child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                          color: TheyDiColors.card,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: TheyDiColors.divider)),
                                      child: const Icon(Icons.group_outlined,
                                          color: TheyDiColors.textSecondary,
                                          size: 20)),
                                ),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                
                                
                                Text('Discover Gatherings',
                                    style: TheyDiTextStyles.displaySmall),
                              ]),
                        ],
                      ).animate().fade(duration: 400.ms),

                      const SizedBox(height: 20),

                      // Search bar — no tune icon inside
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push(AppRoutes.search),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                  color: TheyDiColors.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: TheyDiColors.divider)),
                              child: Row(children: [
                                const SizedBox(width: 12),
                                const Icon(Icons.search,
                                    color: TheyDiColors.textMuted, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text('Search events near you...',
                                        style: TheyDiTextStyles.bodySmall
                                            .copyWith(
                                                color:
                                                    TheyDiColors.textMuted))),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        eventsAsync.maybeWhen(
                          data: (events) => GestureDetector(
                            onTap: () => _openMapView(events),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                  color: TheyDiColors.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: TheyDiColors.divider)),
                              child: const Icon(Icons.map_outlined,
                                  color: TheyDiColors.textSecondary, size: 20),
                            ),
                          ),
                          orElse: () => Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: TheyDiColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: TheyDiColors.divider)),
                            child: const Icon(Icons.map_outlined,
                                color: TheyDiColors.textMuted, size: 20),
                          ),
                        ),
                      ]).animate(delay: 100.ms).fade(duration: 400.ms),

                      const SizedBox(height: 16),

                      // Filters & Location
// Filters & Location
Builder(
  builder: (context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final chipHeight = isMobile ? 30.0 : 34.0;
    final chipPadding = isMobile ? 8.0 : 12.0;
    final iconSize = isMobile ? 12.0 : 14.0;
    final fontSize = isMobile ? 10.5 : 12.0;

    Widget chip({
      required Widget child,
      required VoidCallback onTap,
      bool selected = false,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: chipHeight,
          padding: EdgeInsets.symmetric(horizontal: chipPadding),
          decoration: BoxDecoration(
            color: selected
                ? TheyDiColors.primary.withValues(alpha: 0.15)
                : TheyDiColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? TheyDiColors.primary
                  : TheyDiColors.divider,
            ),
          ),
          child: child,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: isMobile
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            child: Row(
              children: [
                chip(
                  onTap: _showRadiusSelector,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radar,
                          size: iconSize,
                          color: TheyDiColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        _radiusLabel,
                        style: TheyDiTextStyles.caption.copyWith(
                          fontSize: fontSize,
                          color: TheyDiColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isMobile) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down,
                            size: iconSize,
                            color: TheyDiColors.primary),
                      ]
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                chip(
                  selected: _selectedSort == 'Date',
                  onTap: () =>
                      setState(() => _selectedSort = 'Date'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule,
                          size: iconSize,
                          color: _selectedSort == 'Date'
                              ? TheyDiColors.primary
                              : TheyDiColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        "Date",
                        style: TheyDiTextStyles.caption.copyWith(
                          fontSize: fontSize,
                          color: _selectedSort == 'Date'
                              ? TheyDiColors.primary
                              : TheyDiColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                chip(
                  selected: _selectedSort == 'Price ₹',
                  onTap: () {
                    setState(() {
                      if (_selectedSort == 'Price ₹') {
                        _priceAscending = !_priceAscending;
                      }
                      _selectedSort = 'Price ₹';
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.currency_rupee,
                          size: iconSize,
                          color: _selectedSort == 'Price ₹'
                              ? TheyDiColors.primary
                              : TheyDiColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _selectedSort == 'Price ₹'
                            ? (_priceAscending
                                ? "Price ↑"
                                : "Price ↓")
                            : "Price",
                        style: TheyDiTextStyles.caption.copyWith(
                          fontSize: fontSize,
                          color: _selectedSort == 'Price ₹'
                              ? TheyDiColors.primary
                              : TheyDiColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Location fixed on right
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on,
                size: iconSize,
                color: TheyDiColors.primary),
            const SizedBox(width: 3),
            Text(
              userCity.isNotEmpty
                  ? '$userCity, India'
                  : 'All Cities',
              style: TheyDiTextStyles.caption.copyWith(
                fontSize: fontSize,
                color: TheyDiColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            if (_locationLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_userLat != null)
              const Icon(
                Icons.gps_fixed,
                color: Colors.green,
                size: 12,
              )
            else
              GestureDetector(
                onTap: _loadUserLocation,
                child: const Icon(
                  Icons.gps_off,
                  size: 12,
                  color: TheyDiColors.textMuted,
                ),
              ),
          ],
        ),
      ],
    );
  },
).animate(delay: 150.ms).fade(duration: 400.ms),

                      const SizedBox(height: 14),

                      // Category chips
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final isSelected = cat == _selectedCategory;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? TheyDiColors.gradientPrimary
                                      : null,
                                  color: isSelected ? null : TheyDiColors.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: isSelected
                                          ? Colors.transparent
                                          : TheyDiColors.divider),
                                ),
                                child: Center(
                                    child: Text(cat,
                                        style: TheyDiTextStyles.labelMedium
                                            .copyWith(
                                                color: isSelected
                                                    ? Colors.white
                                                    : TheyDiColors
                                                        .textSecondary))),
                              ),
                            );
                          },
                        ),
                      ).animate(delay: 200.ms).fade(duration: 400.ms),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              eventsAsync.when(
                loading: () => const SliverToBoxAdapter(
                    child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: TheyDiColors.primary)))),
                error: (e, _) => SliverToBoxAdapter(
                    child: Center(
                        child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text('Failed to load events: $e',
                                style: TheyDiTextStyles.bodySmall)))),
                data: (allEvents) {
                  final filtered = _filterAndSortEvents(allEvents, userCity);
                  final topEvents = _topEventsForLocation(allEvents, userCity);
                  final locationLabel =
                      userCity.isEmpty ? 'Your Location' : userCity;

                  return SliverMainAxisGroup(
                    slivers: [
                      if (filtered.isEmpty)
                        SliverToBoxAdapter(
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 40),
                                child: Column(children: [
                                  Icon(Icons.event_busy,
                                      size: 64, color: Colors.grey[700]),
                                  const SizedBox(height: 16),
                                  Text('No events found',
                                      style: TheyDiTextStyles.headlineMedium),
                                  const SizedBox(height: 8),
                                  Text(
                                      _selectedRadius > 0
                                          ? 'No events within $_radiusLabel. Try expanding the radius.'
                                          : _selectedCategory != 'All'
                                              ? 'Try a different category'
                                              : 'Be the first to create an event!',
                                      style: TheyDiTextStyles.bodySmall
                                          .copyWith(
                                              color:
                                                  TheyDiColors.textSecondary),
                                      textAlign: TextAlign.center),
                                ])))
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${filtered.length} event${filtered.length == 1 ? '' : 's'} near you',
                                    style: TheyDiTextStyles.labelLarge),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 420,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final cardWidth = math
                                          .min(
                                              360,
                                              math.max(280,
                                                  constraints.maxWidth * 0.85))
                                          .toDouble();
                                      return ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        physics: const ClampingScrollPhysics(),
                                        padding:
                                            const EdgeInsets.only(right: 20),
                                        primary: false,
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(width: 16),
                                        itemBuilder: (context, index) {
                                          final event = filtered[index];
                                          return SizedBox(
                                            width: cardWidth,
                                            child: _EventCard(
                                                    event: event,
                                                    distance: _getEventDistance(
                                                        event))
                                                .animate(
                                                    delay: Duration(
                                                        milliseconds:
                                                            100 * index))
                                                .fade(duration: 400.ms)
                                                .slideY(begin: 0.2, end: 0),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      _EventSectionHeader(
                        title: 'Top Events in $locationLabel',
                        subtitle: 'Ranked by current registrations',
                      ),
                      if (topEvents.isEmpty)
                        const SliverToBoxAdapter(
                          child: _EmptySectionMessage(
                              message:
                                  'No events found for this location yet.'),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final event = topEvents[index];
                                return _EventCard(
                                  event: event,
                                  distance: _getEventDistance(event),
                                )
                                    .animate(
                                      delay: Duration(milliseconds: 75 * index),
                                    )
                                    .fade(duration: 350.ms)
                                    .slideY(begin: 0.08, end: 0);
                              },
                              childCount: topEvents.length,
                            ),
                          ),
                        ),
                      const _EventSectionHeader(
                        title: 'All Events',
                        subtitle: 'Events available globally',
                      ),
                      if (allEvents.isEmpty)
                        const SliverToBoxAdapter(
                          child: _EmptySectionMessage(
                              message: 'No global events available yet.'),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final event = allEvents[index];
                                return _EventCard(
                                  event: event,
                                  distance: _getEventDistance(event),
                                );
                              },
                              childCount: allEvents.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EventSectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TheyDiTextStyles.labelLarge),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  final String message;

  const _EmptySectionMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Text(
        message,
        style: TheyDiTextStyles.bodySmall
            .copyWith(color: TheyDiColors.textSecondary),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  final double distance;
  const _EventCard({required this.event, required this.distance});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d · h:mm a').format(event.dateTime);
    final distanceLabel = LocationService.formatDistance(distance);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TheyDiColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          GestureDetector(
            onTap: () => context.push('/event/${event.id}', extra: event),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: event.allImages.isNotEmpty
                  ? Image.network(
                      event.allImages.first,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        decoration: const BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                        ),
                      ),
                    )
                  : Container(
                      height: 120,
                      decoration: const BoxDecoration(
                        gradient: TheyDiColors.gradientPrimary,
                      ),
                    ),
            ),
          ),
          if (event.isOngoing)
            Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('Live',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: Colors.white)),
                  ]),
                ))
          else
            Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(event.category,
                      style: TheyDiTextStyles.caption
                          .copyWith(color: Colors.white)),
                )),
          Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: event.isFree
                        ? Colors.green
                        : Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(event.isFree ? 'FREE' : '₹${event.price.toInt()}',
                    style: TheyDiTextStyles.labelMedium
                        .copyWith(color: Colors.white)),
              )),
          if (distanceLabel.isNotEmpty)
            Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.near_me, size: 10, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(distanceLabel,
                        style: TheyDiTextStyles.caption
                            .copyWith(color: Colors.white70, fontSize: 10)),
                  ]),
                )),
        ]),
        GestureDetector(
          onTap: () => context.push('/event/${event.id}', extra: event),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text(event.title,
                                  style: TheyDiTextStyles.headlineMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          if (event.ageGroup.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: TheyDiColors.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(event.ageGroup,
                                    style: TheyDiTextStyles.caption.copyWith(
                                        color: TheyDiColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600))),
                          ],
                        ]),
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(event.description,
                          style: TheyDiTextStyles.caption.copyWith(
                              color: TheyDiColors.textSecondary, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis)
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: TheyDiColors.textMuted),
                      const SizedBox(width: 4),
                      Text(dateStr, style: TheyDiTextStyles.caption)
                    ]),
                    const SizedBox(height: 4),
                    if (distanceLabel.isNotEmpty) ...[
                      Row(children: [
                        const Icon(Icons.near_me,
                            size: 14, color: TheyDiColors.primary),
                        const SizedBox(width: 4),
                        Text(distanceLabel,
                            style: TheyDiTextStyles.caption
                                .copyWith(color: TheyDiColors.primary))
                      ]),
                      const SizedBox(height: 4)
                    ],
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: TheyDiColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(event.location,
                              style: TheyDiTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis))
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Row(children: [
                        const Icon(Icons.people_outline,
                            size: 14, color: TheyDiColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                            '${event.currentAttendees} / ${event.maxAttendees} going',
                            style: TheyDiTextStyles.caption.copyWith(
                                color: event.spotsLeft < 5
                                    ? TheyDiColors.error
                                    : TheyDiColors.textMuted))
                      ]),
                      if (event.durationHours > 0) ...[
                        const SizedBox(width: 10),
                        Row(children: [
                          const Icon(Icons.timer_outlined,
                              size: 14, color: TheyDiColors.textMuted),
                          const SizedBox(width: 4),
                          Text('${event.durationHours}h',
                              style: TheyDiTextStyles.caption
                                  .copyWith(color: TheyDiColors.textMuted))
                        ])
                      ],
                      const Spacer(),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              gradient: TheyDiColors.gradientPrimary,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('View',
                              style: TheyDiTextStyles.labelMedium
                                  .copyWith(color: Colors.white))),
                    ]),
                  ])),
        ),
      ]),
    );
  }
}
