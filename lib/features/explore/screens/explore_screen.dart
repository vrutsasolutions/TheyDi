import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/event_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/filter_bottom_sheet.dart';
import '../../../shared/widgets/notification_icon_button.dart';
import '../../events/models/event_model.dart';

// Stream ALL events from Firestore (India-wide)
final _allIndiaEventsProvider =
    StreamProvider.autoDispose<List<EventModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('events')
      .orderBy('dateTime')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList());
});

// The signed-in user's home city, used to default the Explore screen to a
// specific city (rather than all of India) until they pick a different one
// or flip on the All India toggle. Same source as the Home screen's city.
final _userCityProvider = StreamProvider.autoDispose<String>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value('');
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => (doc.data()?['city'] as String?) ?? '');
});

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String _selectedFilter = 'All';
  final EventFilters _advancedFilters = EventFilters();

  // Popular cities shown as a quick-pick strip. Tapping one scopes the
  // whole screen to that city (same mechanism as picking a city from the
  // Filters sheet).
  static const List<String> _topCities = [
    'Bengaluru',
    'Mumbai',
    'Delhi',
    'Chennai',
    'Hyderabad',
    'Kolkata',
    'Pune',
    'Ahmedabad',
    'Jaipur',
    'Chandigarh',
    'Lucknow',
    'Kochi',
  ];

  // When true, ignore any selected city entirely and show events from
  // across India.
  bool _allIndia = false;

  void _selectCity(String city) {
    setState(() {
      _advancedFilters.city = city;
      _allIndia = false;
    });
  }

  void _toggleAllIndia(bool value) {
    setState(() => _allIndia = value);
  }

  // Resolves the city the screen is currently scoped to: null means "no
  // city scoping — show everything". All India always wins; otherwise an
  // explicitly picked city wins; otherwise fall back to the user's own
  // city if we know it.
  String? _resolveActiveCity(String userCity) {
    if (_allIndia) return null;
    if (_advancedFilters.city != null && _advancedFilters.city!.isNotEmpty) {
      return _advancedFilters.city;
    }
    return userCity.isNotEmpty ? userCity : null;
  }

  // ── FIX: this now actually EXCLUDES events that don't match the
  // selected quick filter (Today / Free / This Week), instead of just
  // sorting matches to the top while keeping every event in the list.
  // Advanced-filter score and chronological order are only used as
  // tiebreakers among events that already passed the quick filter. ──
  bool _matchesQuickFilter(EventModel e, DateTime today, DateTime weekLater) {
    switch (_selectedFilter) {
      case 'Today':
        return e.dateTime.year == today.year &&
            e.dateTime.month == today.month &&
            e.dateTime.day == today.day;
      case 'Free':
        return e.isFree;
      case 'This Week':
        return e.dateTime.isAfter(today.subtract(const Duration(seconds: 1))) &&
            e.dateTime.isBefore(weekLater);
      case 'All':
      default:
        return true;
    }
  }

  // ── FIX: advanced filters (category/city/free/maxPrice/date range) now
  // actually EXCLUDE non-matching events instead of only nudging the sort
  // order. Previously each active filter added a "score" point to matching
  // events but never removed anything, so e.g. setting a 25-26 Aug date
  // range still left an Aug 31 or Sep 1 event visible in the list — it was
  // just sorted lower. ──
  // ── NOTE: city is intentionally NOT checked here anymore. It's handled
  // by the `activeCity` parameter on `_applyQuickFilter` instead, so that
  // the All India toggle and the "default to my city" fallback both flow
  // through a single place. ──
  bool _matchesAdvancedFilters(EventModel e) {
    if (_advancedFilters.category != null &&
        e.category != _advancedFilters.category) {
      return false;
    }
    if (_advancedFilters.freeOnly == true && !e.isFree) {
      return false;
    }
    if (_advancedFilters.maxPrice != null &&
        !e.isFree &&
        e.price > _advancedFilters.maxPrice!) {
      return false;
    }
    if (_advancedFilters.dateFrom != null &&
        e.dateTime.isBefore(_advancedFilters.dateFrom!)) {
      return false;
    }
    if (_advancedFilters.dateTo != null) {
      final endOfDay =
          _advancedFilters.dateTo!.add(const Duration(hours: 23, minutes: 59));
      if (e.dateTime.isAfter(endOfDay)) {
        return false;
      }
    }
    return true;
  }

  List<EventModel> _applyQuickFilter(List<EventModel> events,
      {String? activeCity}) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime weekLater = today.add(const Duration(days: 7));

    debugPrint(
        'EXPLORE_DEBUG: _applyQuickFilter called. Filter: $_selectedFilter. City: $activeCity. Events count: ${events.length}');

    // Actually drop events that don't match the selected quick filter,
    // the advanced filters from the Filters sheet, AND the active city
    // (unless we're in All India mode, where activeCity is null).
    final matching = events
        .where((e) =>
            _matchesQuickFilter(e, today, weekLater) &&
            _matchesAdvancedFilters(e) &&
            (activeCity == null ||
                e.city.toLowerCase() == activeCity.toLowerCase()))
        .toList();

    final sorted = List<EventModel>.from(matching)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    debugPrint(
        'EXPLORE_DEBUG: Filter+sort finished. Matching count: ${sorted.length}. Top 3 titles: ${sorted.take(3).map((e) => e.title).toList()}');
    return sorted;
  }

  // ── FIX: segments now filter down to quick-filter matches first (same
  // as _applyQuickFilter), then sort the remaining events by the section's
  // own secondary criteria (e.g. attendees for Trending). Previously this
  // only used the quick filter as a sort key, so non-matching events (e.g.
  // events not happening today) still showed up under every section. ──
  List<EventModel> _sortSegment(List<EventModel> events,
      int Function(EventModel a, EventModel b) secondaryComparator) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekLater = today.add(const Duration(days: 7));

    // Start with all upcoming events that also match the quick filter.
    final list = events
        .where((e) =>
            e.dateTime.isAfter(now) && _matchesQuickFilter(e, today, weekLater))
        .toList();

    list.sort(secondaryComparator);

    return list.take(6).toList();
  }

  List<EventModel> _getTrending(List<EventModel> events) {
    return _sortSegment(
        events, (a, b) => b.currentAttendees.compareTo(a.currentAttendees));
  }

  List<EventModel> _getMostPopular(List<EventModel> events) {
    final popularCandidates = events.where((e) => !e.isFull).toList();
    return _sortSegment(popularCandidates,
        (a, b) => b.currentAttendees.compareTo(a.currentAttendees));
  }

  List<EventModel> _getHouseParties(List<EventModel> events) {
    final partyCandidates = events
        .where((e) =>
            e.category.toLowerCase() == 'party' ||
            e.category.toLowerCase() == 'social' ||
            e.title.toLowerCase().contains('party') ||
            e.description.toLowerCase().contains('party') ||
            e.title.toLowerCase().contains('house') ||
            e.description.toLowerCase().contains('house'))
        .toList();

    return _sortSegment(
        partyCandidates, (a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<EventModel> _getNewlyAdded(List<EventModel> events) {
    return _sortSegment(events, (a, b) {
      final aDate = a.createdAt ?? DateTime(2000);
      final bDate = b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(_allIndiaEventsProvider);
    final userCityAsync = ref.watch(_userCityProvider);
    final userCity = userCityAsync.asData?.value ?? '';
    final activeCity = _resolveActiveCity(userCity);
    final showingAllIndia = activeCity == null;
    final cityLabel = activeCity ?? 'All India';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 255, 255, 255)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: eventsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: TheyDiColors.primary),
            ),
            error: (e, _) => Center(
              child:
                  Text('Failed to load: $e', style: TheyDiTextStyles.bodySmall),
            ),
            data: (allEvents) {
              final filtered =
                  _applyQuickFilter(allEvents, activeCity: activeCity);
              final trending = _getTrending(filtered);
              final popular = _getMostPopular(filtered);
              final parties = _getHouseParties(filtered);
              final newEvents = _getNewlyAdded(filtered);

              return CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Row(
                            children: [
                              Text('Explore',
                                  style: TheyDiTextStyles.displayMedium),
                              const Spacer(),
                              Icon(
                                  showingAllIndia
                                      ? Icons.public
                                      : Icons.location_on,
                                  size: 16, color: TheyDiColors.primary),
                              const SizedBox(width: 4),
                              Text(cityLabel,
                                  style: TheyDiTextStyles.caption.copyWith(
                                    color: TheyDiColors.primary,
                                    fontWeight: FontWeight.w600,
                                  )),
                              const SizedBox(width: 12),
                              const NotificationIconButton(),
                            ],
                          ).animate().fade(duration: 400.ms),

                          const SizedBox(height: 16),

                         // Search bar
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.search),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: TheyDiColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TheyDiColors.divider),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  const Icon(Icons.search,
                                      color: TheyDiColors.textMuted, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Search events across India...',
                                      style:
                                          TheyDiTextStyles.bodySmall.copyWith(
                                        color: TheyDiColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  // Container(
                                  //   margin: const EdgeInsets.only(right: 8),
                                  //   padding: const EdgeInsets.all(8),
                                  //   decoration: BoxDecoration(
                                  //     color: TheyDiColors.primary
                                  //         .withValues(alpha: 0.15),
                                  //     borderRadius: BorderRadius.circular(8),
                                  //   ),
                                  //   child: const Icon(Icons.tune,
                                  //       color: TheyDiColors.primary, size: 16),
                                  // ),
                                ],
                              ),
                            ),
                          ).animate(delay: 100.ms).fade(duration: 400.ms),

                          const SizedBox(height: 14),

                          // All India toggle
                          Row(
                            children: [
                              Text('All India',
                                  style: TheyDiTextStyles.labelMedium
                                      .copyWith(
                                          color: TheyDiColors.textSecondary)),
                              const Spacer(),
                              Transform.scale(
                                scale: 0.8,
                                child: Switch(
                                  value: _allIndia,
                                  onChanged: _toggleAllIndia,
                                  activeColor: TheyDiColors.primary,
                                ),
                              ),
                            ],
                          ).animate(delay: 120.ms).fade(duration: 400.ms),

                          const SizedBox(height: 10),

                          // Top Cities — boxy tiles (each one's a slot for
                          // a city photo later; for now just an icon +
                          // name placeholder).
                          SizedBox(
                            height: 84,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _topCities.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final city = _topCities[index];
                                final isSelected =
                                    !showingAllIndia && activeCity == city;
                                return _PressableScale(
                                  onTap: () => _selectCity(city),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    width: 96,
                                    decoration: BoxDecoration(
                                      gradient: isSelected
                                          ? TheyDiColors.gradientPrimary
                                          : null,
                                      color:
                                          isSelected ? null : TheyDiColors.card,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.transparent
                                            : TheyDiColors.divider,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelected
                                              ? TheyDiColors.primary
                                                  .withValues(alpha: 0.3)
                                              : Colors.black
                                                  .withValues(alpha: 0.04),
                                          blurRadius: isSelected ? 10 : 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // TODO: swap for Image.network(cityImageUrl)
                                        // once city photos are available.
                                        Positioned.fill(
                                          child: Center(
                                            child: Icon(
                                              Icons.location_city_rounded,
                                              size: 26,
                                              color: isSelected
                                                  ? Colors.white
                                                      .withValues(alpha: 0.9)
                                                  : TheyDiColors.textMuted,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 6,
                                          right: 6,
                                          bottom: 8,
                                          child: Text(
                                            city,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TheyDiTextStyles.caption
                                                .copyWith(
                                              color: isSelected
                                                  ? Colors.white
                                                  : TheyDiColors
                                                      .textSecondary,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ).animate(delay: 140.ms).fade(duration: 400.ms),

                          const SizedBox(height: 10),

                          // "Showing experiences in X" banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: TheyDiColors.gradientPrimary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: TheyDiColors.primary
                                      .withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              showingAllIndia
                                  ? 'Showing all experiences across India'
                                  : 'Showing experiences in $activeCity',
                              style: TheyDiTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ).animate(delay: 160.ms).fade(duration: 400.ms),

                          const SizedBox(height: 14),

                          // Filter chips + advanced filter
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 32,
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    scrollDirection: Axis.horizontal,
                                    itemCount:
                                        EventConstants.exploreFilters.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 6),
                                    itemBuilder: (context, index) {
                                      final filter =
                                          EventConstants.exploreFilters[index];
                                      final isSelected =
                                          filter == _selectedFilter;

                                      return _PressableScale(
                                        onTap: () {
                                          setState(() {
                                            _selectedFilter = filter;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? TheyDiColors.gradientPrimary
                                                : null,
                                            color: isSelected
                                                ? null
                                                : TheyDiColors.card,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.transparent
                                                  : TheyDiColors.divider,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: TheyDiColors
                                                          .primary
                                                          .withValues(
                                                              alpha: 0.25),
                                                      blurRadius: 6,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Center(
                                            child: Text(
                                              filter,
                                              style: TheyDiTextStyles.caption
                                                  .copyWith(
                                                fontSize: 11,
                                                color: isSelected
                                                    ? Colors.white
                                                    : TheyDiColors
                                                        .textSecondary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _PressableScale(
                                  onTap: () {
                                    FilterBottomSheet.show(
                                      context: context,
                                      filters: _advancedFilters,
                                      onApply: (filters) {
                                        setState(() {
                                          _advancedFilters.category =
                                              filters.category;
                                          _advancedFilters.city = filters.city;
                                          if (filters.city != null &&
                                              filters.city!.isNotEmpty) {
                                            _allIndia = false;
                                          }
                                          _advancedFilters.freeOnly =
                                              filters.freeOnly;
                                          _advancedFilters.maxPrice =
                                              filters.maxPrice;
                                          _advancedFilters.dateFrom =
                                              filters.dateFrom;
                                          _advancedFilters.dateTo =
                                              filters.dateTo;
                                        });
                                      },
                                    );
                                  },
                                  child: Container(
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: _advancedFilters.hasActiveFilters
                                          ? TheyDiColors.primary
                                              .withValues(alpha: .15)
                                          : TheyDiColors.card,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _advancedFilters.hasActiveFilters
                                            ? TheyDiColors.primary
                                            : TheyDiColors.divider,
                                      ),
                                      boxShadow: _advancedFilters
                                              .hasActiveFilters
                                          ? [
                                              BoxShadow(
                                                color: TheyDiColors.primary
                                                    .withValues(alpha: 0.2),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.tune,
                                          size: 15,
                                          color:
                                              _advancedFilters.hasActiveFilters
                                                  ? TheyDiColors.primary
                                                  : TheyDiColors.textSecondary,
                                        ),
                                        if (_advancedFilters.activeCount >
                                            0) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            "${_advancedFilters.activeCount}",
                                            style: TheyDiTextStyles.caption
                                                .copyWith(
                                              fontSize: 10,
                                              color: TheyDiColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // === SECTIONS ===

                  // Trending Events
                  if (trending.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _HorizontalSection(
                        title: showingAllIndia
                            ? 'Trending Across India'
                            : 'Trending in $activeCity',
                        subtitle: 'Most popular upcoming events',
                        icon: Icons.local_fire_department,
                        iconColor: Colors.orange,
                        events: trending,
                      ).animate(delay: 200.ms).fade(duration: 400.ms),
                    ),

                  // Communities — placeholder heading until the communities
                  // feature is wired up here; real data will replace this.
                  SliverToBoxAdapter(
                    child: _ExplorePlaceholderSection(
                      title: showingAllIndia
                          ? 'Communities Across India'
                          : 'Communities in $activeCity',
                      subtitle: 'Groups worth joining',
                      icon: Icons.groups_outlined,
                      message:
                          "We're building this out — communities will show up here soon.",
                    ).animate(delay: 250.ms).fade(duration: 400.ms),
                  ),

                  // Most Popular
                  if (popular.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _VerticalSection(
                        title: 'Most Popular',
                        subtitle: 'High engagement events',
                        icon: Icons.star_rounded,
                        iconColor: Colors.amber,
                        events: popular.take(3).toList(),
                      ).animate(delay: 300.ms).fade(duration: 400.ms),
                    ),

                  // House Parties
                  if (parties.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _HorizontalSection(
                        title: 'House Parties',
                        subtitle: 'Private gatherings & apartment events',
                        icon: Icons.celebration,
                        iconColor: Colors.pink,
                        events: parties,
                      ).animate(delay: 400.ms).fade(duration: 400.ms),
                    ),

                  // Newly Added
                  if (newEvents.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _VerticalSection(
                        title: 'Newly Added',
                        subtitle: 'Fresh events just posted',
                        icon: Icons.new_releases_outlined,
                        iconColor: Colors.green,
                        events: newEvents.take(3).toList(),
                      ).animate(delay: 500.ms).fade(duration: 400.ms),
                    ),

                  // All Events (filtered)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Row(
                        children: [
                          Icon(
                              showingAllIndia
                                  ? Icons.public
                                  : Icons.location_on,
                              size: 18, color: TheyDiColors.primary),
                          const SizedBox(width: 8),
                          Text(
                              showingAllIndia
                                  ? 'All Events'
                                  : 'All Events in $activeCity',
                              style: TheyDiTextStyles.labelLarge),
                          const Spacer(),
                          Text(
                            '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                            style: TheyDiTextStyles.caption
                                .copyWith(color: TheyDiColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off,
                                  size: 56, color: Colors.grey[700]),
                              const SizedBox(height: 12),
                              Text('No events found',
                                  style: TheyDiTextStyles.headlineMedium),
                              const SizedBox(height: 6),
                              Text('Try a different filter or category',
                                  style: TheyDiTextStyles.bodySmall.copyWith(
                                      color: TheyDiColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final event = filtered[index];
                            return _ExploreEventCard(event: event)
                                .animate(
                                  delay: Duration(milliseconds: 50 * index),
                                )
                                .fade(duration: 300.ms)
                                .slideX(begin: 0.05, end: 0);
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// SECTION WIDGETS
// ══════════════════════════════════════

// ── Placeholder section (Communities) — heading + a "coming soon" card.
// Swap the body for a real list once a communities data source is wired
// into this screen. ──
class _ExplorePlaceholderSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String message;

  const _ExplorePlaceholderSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: TheyDiColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: TheyDiColors.primary),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TheyDiTextStyles.labelLarge),
                  Text(subtitle,
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: TheyDiColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TheyDiColors.divider),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TheyDiTextStyles.bodySmall
                  .copyWith(color: TheyDiColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Horizontal Scroll Section ──
class _HorizontalSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<EventModel> events;

  const _HorizontalSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TheyDiTextStyles.labelLarge),
                  Text(subtitle,
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _HorizontalEventCard(event: events[index]);
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Vertical Scroll Section ──
class _VerticalSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<EventModel> events;

  const _VerticalSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TheyDiTextStyles.labelLarge),
                  Text(subtitle,
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children:
                events.map((event) => _ExploreEventCard(event: event)).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Horizontal Event Card (Trending / House Parties sections) ──
class _HorizontalEventCard extends StatelessWidget {
  final EventModel event;
  const _HorizontalEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d · h:mm a').format(event.dateTime);

    return _PressableScale(
      onTap: () => context.push('/event/${event.id}', extra: event),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TheyDiColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: event.allImages.isNotEmpty
                      ? Image.network(
                          event.allImages.first,
                          height: 90,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 90,
                            decoration: const BoxDecoration(
                              gradient: TheyDiColors.gradientPrimary,
                            ),
                          ),
                        )
                      : Container(
                          height: 90,
                          decoration: const BoxDecoration(
                            gradient: TheyDiColors.gradientPrimary,
                          ),
                        ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(event.category,
                        style: TheyDiTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        )),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: event.isFree
                          ? Colors.green
                          : Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      event.isFree ? 'FREE' : '₹${event.price.toInt()}',
                      style: TheyDiTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(event.title,
                      style: TheyDiTextStyles.labelMedium
                          .copyWith(letterSpacing: -0.1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),

                  // Age Group chip
                  if (event.ageGroup.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: TheyDiColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event.ageGroup,
                        style: TheyDiTextStyles.caption.copyWith(
                          color: TheyDiColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Date
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 10, color: TheyDiColors.textMuted),
                      const SizedBox(width: 4),
                      Text(dateStr,
                          style:
                              TheyDiTextStyles.caption.copyWith(fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 10, color: TheyDiColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('${event.venue}, ${event.city}',
                            style:
                                TheyDiTextStyles.caption.copyWith(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Bottom: going + duration + spots
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 10, color: TheyDiColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${event.currentAttendees} going',
                        style: TheyDiTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: TheyDiColors.primary,
                        ),
                      ),
                      if (event.durationHours > 0) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.timer_outlined,
                            size: 10, color: TheyDiColors.textMuted),
                        const SizedBox(width: 2),
                        Text(
                          '${event.durationHours}h',
                          style: TheyDiTextStyles.caption.copyWith(
                              fontSize: 10, color: TheyDiColors.textMuted),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        '${event.spotsLeft} left',
                        style: TheyDiTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: event.spotsLeft < 5
                              ? TheyDiColors.error
                              : TheyDiColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Explore Event Card (compact list — Most Popular, Newly Added, All Events) ──
class _ExploreEventCard extends StatelessWidget {
  final EventModel event;
  const _ExploreEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d · h:mm a').format(event.dateTime);

    return _PressableScale(
      onTap: () => context.push('/event/${event.id}', extra: event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TheyDiColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left color block
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: event.allImages.isNotEmpty
                  ? Image.network(
                      event.allImages.first,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                        ),
                        child: Center(
                          child: Text(
                            event.category.isNotEmpty ? event.category[0] : 'E',
                            style: TheyDiTextStyles.displayMedium.copyWith(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: TheyDiColors.gradientPrimary,
                      ),
                      child: Center(
                        child: Text(
                          event.category.isNotEmpty ? event.category[0] : 'E',
                          style: TheyDiTextStyles.displayMedium.copyWith(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(event.title,
                      style: TheyDiTextStyles.labelLarge
                          .copyWith(letterSpacing: -0.1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),

                  // Description snippet
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.description,
                      style: TheyDiTextStyles.caption.copyWith(
                        color: TheyDiColors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Date
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 11, color: TheyDiColors.textMuted),
                      const SizedBox(width: 4),
                      Text(dateStr, style: TheyDiTextStyles.caption),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 11, color: TheyDiColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('${event.venue}, ${event.city}',
                            style: TheyDiTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),

                  // Age Group + Duration row
                  if (event.ageGroup.isNotEmpty || event.durationHours > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (event.ageGroup.isNotEmpty) ...[
                          Icon(Icons.people_outline,
                              size: 11, color: TheyDiColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            event.ageGroup,
                            style: TheyDiTextStyles.caption.copyWith(
                              color: TheyDiColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                        if (event.ageGroup.isNotEmpty &&
                            event.durationHours > 0)
                          const SizedBox(width: 10),
                        if (event.durationHours > 0) ...[
                          Icon(Icons.timer_outlined,
                              size: 11, color: TheyDiColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            '${event.durationHours} hr${event.durationHours > 1 ? 's' : ''}',
                            style: TheyDiTextStyles.caption.copyWith(
                              color: TheyDiColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Price + attendees (right column)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${event.currentAttendees} going',
                  style: TheyDiTextStyles.caption.copyWith(
                    color: TheyDiColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tiny reusable press-scale wrapper — gentle scale-down on tap-down /
// spring-back on release, so tiles/chips/cards feel a bit more tactile.
// Purely visual; the actual tap logic still lives in the child's onTap. ──
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}