import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/filter_bottom_sheet.dart';
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

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String _selectedFilter = 'All';
  final EventFilters _advancedFilters = EventFilters();

  final List<String> _filters = ['All', 'Today', 'Free', 'This Week'];

  List<EventModel> _applyQuickFilter(List<EventModel> events) {
    var filtered = events;

    switch (_selectedFilter) {
      case 'Today':
        final now = DateTime.now();
        filtered = filtered
            .where((e) =>
                e.dateTime.day == now.day &&
                e.dateTime.month == now.month &&
                e.dateTime.year == now.year)
            .toList();
        break;
      case 'Free':
        filtered = filtered.where((e) => e.isFree).toList();
        break;
      case 'This Week':
        final weekLater = DateTime.now().add(const Duration(days: 7));
        filtered =
            filtered.where((e) => e.dateTime.isBefore(weekLater)).toList();
        break;
    }

    // Advanced filters
    if (_advancedFilters.category != null) {
      filtered = filtered
          .where((e) => e.category == _advancedFilters.category)
          .toList();
    }
    if (_advancedFilters.city != null) {
      filtered = filtered
          .where((e) =>
              e.city.toLowerCase() ==
              _advancedFilters.city!.toLowerCase())
          .toList();
    }
    if (_advancedFilters.freeOnly == true) {
      filtered = filtered.where((e) => e.isFree).toList();
    }
    if (_advancedFilters.maxPrice != null) {
      filtered = filtered
          .where((e) => e.isFree || e.price <= _advancedFilters.maxPrice!)
          .toList();
    }
    if (_advancedFilters.dateFrom != null) {
      filtered = filtered
          .where((e) => e.dateTime.isAfter(_advancedFilters.dateFrom!))
          .toList();
    }
    if (_advancedFilters.dateTo != null) {
      final endOfDay = _advancedFilters.dateTo!
          .add(const Duration(hours: 23, minutes: 59));
      filtered =
          filtered.where((e) => e.dateTime.isBefore(endOfDay)).toList();
    }

    return filtered;
  }

  // Trending = upcoming events with most attendees
  List<EventModel> _getTrending(List<EventModel> events) {
    final upcoming =
        events.where((e) => e.dateTime.isAfter(DateTime.now())).toList();
    upcoming.sort((a, b) => b.currentAttendees.compareTo(a.currentAttendees));
    return upcoming.take(6).toList();
  }

  // Most Popular = highest attendees + not full
  List<EventModel> _getMostPopular(List<EventModel> events) {
    final popular = events
        .where((e) => e.dateTime.isAfter(DateTime.now()) && !e.isFull)
        .toList();
    popular.sort((a, b) => b.currentAttendees.compareTo(a.currentAttendees));
    return popular.take(6).toList();
  }

  // House Parties = category is Party or Social
  List<EventModel> _getHouseParties(List<EventModel> events) {
    return events
        .where((e) =>
            e.dateTime.isAfter(DateTime.now()) &&
            (e.category.toLowerCase() == 'party' ||
                e.category.toLowerCase() == 'social' ||
                e.title.toLowerCase().contains('party') ||
                e.description.toLowerCase().contains('party') ||
                e.title.toLowerCase().contains('house') ||
                e.description.toLowerCase().contains('house')))
        .take(6)
        .toList();
  }

  // Newly Added = sorted by createdAt descending
  List<EventModel> _getNewlyAdded(List<EventModel> events) {
    final sorted = events
        .where((e) => e.dateTime.isAfter(DateTime.now()))
        .toList();
    sorted.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(2000);
      final bDate = b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return sorted.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(_allIndiaEventsProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 255, 255, 255), Color.fromARGB(255, 255, 255, 255)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: eventsAsync.when(
            loading: () => const Center(
              child:
                  CircularProgressIndicator(color: TheyDiColors.primary),
            ),
            error: (e, _) => Center(
              child: Text('Failed to load: $e',
                  style: TheyDiTextStyles.bodySmall),
            ),
            data: (allEvents) {
              final filtered = _applyQuickFilter(allEvents);
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
                              Text('All India',
                                  style: TheyDiTextStyles.caption.copyWith(
                                    color: TheyDiColors.primary,
                                  )),
                              const SizedBox(width: 4),
                              Icon(Icons.public,
                                  size: 16, color: TheyDiColors.primary),
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
                                border: Border.all(
                                    color: TheyDiColors.divider),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  const Icon(Icons.search,
                                      color: TheyDiColors.textMuted,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Search events across India...',
                                      style: TheyDiTextStyles.bodySmall
                                          .copyWith(
                                        color: TheyDiColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin:
                                        const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: TheyDiColors.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.tune,
                                        color: TheyDiColors.primary,
                                        size: 16),
                                  ),
                                ],
                              ),
                            ),
                          ).animate(delay: 100.ms).fade(duration: 400.ms),

                          const SizedBox(height: 14),

                          // Filter chips + advanced filter
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 36,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _filters.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      final filter = _filters[index];
                                      final isSelected =
                                          filter == _selectedFilter;
                                      return GestureDetector(
                                        onTap: () => setState(() =>
                                            _selectedFilter = filter),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16),
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? TheyDiColors
                                                    .gradientPrimary
                                                : null,
                                            color: isSelected
                                                ? null
                                                : TheyDiColors.card,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    20),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.transparent
                                                  : TheyDiColors.divider,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(filter,
                                                style: TheyDiTextStyles
                                                    .labelMedium
                                                    .copyWith(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : TheyDiColors
                                                          .textSecondary,
                                                )),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  FilterBottomSheet.show(
                                    context: context,
                                    filters: _advancedFilters,
                                    onApply: (filters) {
                                      setState(() {
                                        _advancedFilters.category =
                                            filters.category;
                                        _advancedFilters.city =
                                            filters.city;
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
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: _advancedFilters
                                            .hasActiveFilters
                                        ? TheyDiColors.primary
                                            .withValues(alpha: 0.2)
                                        : TheyDiColors.card,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _advancedFilters
                                              .hasActiveFilters
                                          ? TheyDiColors.primary
                                          : TheyDiColors.divider,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.tune,
                                          size: 16,
                                          color: _advancedFilters
                                                  .hasActiveFilters
                                              ? TheyDiColors.primary
                                              : TheyDiColors
                                                  .textSecondary),
                                      if (_advancedFilters.activeCount >
                                          0) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          width: 18,
                                          height: 18,
                                          decoration:
                                              const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: TheyDiColors.primary,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${_advancedFilters.activeCount}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                              .animate(delay: 150.ms)
                              .fade(duration: 400.ms),

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
                        title: 'Trending in India',
                        subtitle: 'Most popular upcoming events',
                        icon: Icons.local_fire_department,
                        iconColor: Colors.orange,
                        events: trending,
                      )
                          .animate(delay: 200.ms)
                          .fade(duration: 400.ms),
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
                      )
                          .animate(delay: 300.ms)
                          .fade(duration: 400.ms),
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
                      )
                          .animate(delay: 400.ms)
                          .fade(duration: 400.ms),
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
                      )
                          .animate(delay: 500.ms)
                          .fade(duration: 400.ms),
                    ),

                  // All Events (filtered)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.public,
                              size: 18, color: TheyDiColors.primary),
                          const SizedBox(width: 8),
                          Text('All Events',
                              style: TheyDiTextStyles.labelLarge),
                          const Spacer(),
                          Text(
                            '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                            style: TheyDiTextStyles.caption.copyWith(
                                color: TheyDiColors.textSecondary),
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
                                  style:
                                      TheyDiTextStyles.headlineMedium),
                              const SizedBox(height: 6),
                              Text(
                                  'Try a different filter or category',
                                  style: TheyDiTextStyles.bodySmall
                                      .copyWith(
                                          color: TheyDiColors
                                              .textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final event = filtered[index];
                            return _ExploreEventCard(event: event)
                                .animate(
                                  delay: Duration(
                                      milliseconds: 50 * index),
                                )
                                .fade(duration: 300.ms)
                                .slideX(begin: 0.05, end: 0);
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(
                      child: SizedBox(height: 100)),
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
            children: events
                .map((event) => _ExploreEventCard(event: event))
                .toList(),
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

    return GestureDetector(
      onTap: () => context.push('/event/${event.id}', extra: event),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
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
                      style: TheyDiTextStyles.labelMedium,
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
                          style: TheyDiTextStyles.caption
                              .copyWith(fontSize: 10)),
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
                            style: TheyDiTextStyles.caption
                                .copyWith(fontSize: 10),
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
                              fontSize: 10,
                              color: TheyDiColors.textMuted),
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

    return GestureDetector(
      onTap: () => context.push('/event/${event.id}', extra: event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TheyDiColors.divider),
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
                      style: TheyDiTextStyles.labelLarge,
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
                  if (event.ageGroup.isNotEmpty ||
                      event.durationHours > 0) ...[
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: event.isFree
                        ? Colors.green.withValues(alpha: 0.15)
                        : TheyDiColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.isFree ? 'FREE' : '₹${event.price.toInt()}',
                    style: TheyDiTextStyles.caption.copyWith(
                      color: event.isFree
                          ? Colors.green
                          : TheyDiColors.primary,
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