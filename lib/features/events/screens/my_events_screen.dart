import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/models/event_model.dart';

class MyEventsScreen extends ConsumerStatefulWidget {
  /// Optional: jump straight to a tab (0=Attending, 1=Requested, 2=Hosting)
  /// and pre-select a role filter ('All' | 'Hosted' | 'Attended')
  final int initialTab;
  final String initialFilter;

  const MyEventsScreen({
    super.key,
    this.initialTab = 0,
    this.initialFilter = 'All',
  });

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: TheyDiColors.textPrimary),
                          onPressed: () => context.go(AppRoutes.profile),
                        ),
                        const SizedBox(width: 4),
                        Text('My Events', style: TheyDiTextStyles.displayMedium)
                            .animate()
                            .fade(duration: 400.ms),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.notifications),
                          child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: TheyDiColors.divider)),
                              child: const Icon(
                                  Icons.notifications_outlined,
                                  color: TheyDiColors.textSecondary,
                                  size: 20)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: TheyDiColors.primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelColor: TheyDiColors.primary,
                      unselectedLabelColor: TheyDiColors.textSecondary,
                      labelStyle: TheyDiTextStyles.labelLarge,
                      tabs: const [
                        Tab(text: 'Attending'),
                        Tab(text: 'Requested'),
                        Tab(text: 'Hosting'),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: uid == null
                    ? const _EmptyState(emoji: '👤', message: 'Not signed in')
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _EventsTab(
                            stream: FirebaseFirestore.instance
                                .collection('events')
                                .where('attendeeUids', arrayContains: uid)
                                .snapshots(),
                            emptyEmoji: '🎉',
                            emptyUpcomingMessage: 'No events joined yet',
                            emptyPastMessage: 'No past events attended',
                            badgeLabel: 'Attending',
                            currentUid: uid,
                            roleLabel: 'Attended',
                          ),
                          _EventsTab(
                            stream: FirebaseFirestore.instance
                                .collection('events')
                                .where('pendingUids', arrayContains: uid)
                                .snapshots(),
                            emptyEmoji: '⏱️',
                            emptyUpcomingMessage: 'No pending requests',
                            emptyPastMessage: 'No past requested events',
                            badgeLabel: 'Requested',
                            currentUid: uid,
                            roleLabel: 'Requested',
                          ),
                          _EventsTab(
                            stream: FirebaseFirestore.instance
                                .collection('events')
                                .where('creatorUid', isEqualTo: uid)
                                .snapshots(),
                            emptyEmoji: '🎪',
                            emptyUpcomingMessage: 'You haven\'t created any events',
                            emptyPastMessage: 'No past hosted events',
                            badgeLabel: 'Hosting',
                            currentUid: uid,
                            roleLabel: 'Hosted',
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createEvent),
        backgroundColor: TheyDiColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Create Event',
            style: TheyDiTextStyles.labelMedium.copyWith(color: Colors.white)),
      ),
    );
  }
}

// ── Active event card (Attending / Created) ──
class _ActiveEventCard extends StatelessWidget {
  final EventModel event;
  final String badgeLabel;
  final String currentUid;

  const _ActiveEventCard({
    required this.event,
    required this.badgeLabel,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d • h:mm a').format(event.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Row(
        children: [
          // Category badge
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                event.category.isNotEmpty ? event.category[0] : 'E',
                style: TheyDiTextStyles.displaySmall.copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Live" badge if ongoing
                if (event.isOngoing)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('🔴 Happening Now',
                        style: TheyDiTextStyles.caption.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 10)),
                  ),
                Text(event.title,
                    style: TheyDiTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(dateStr, style: TheyDiTextStyles.caption),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 11, color: TheyDiColors.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text('${event.venue}, ${event.city}',
                          style: TheyDiTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.group_outlined,
                        size: 11, color: TheyDiColors.textMuted),
                    const SizedBox(width: 3),
                    Text(
                        '${event.currentAttendees}/${event.maxAttendees} attending',
                        style: TheyDiTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            children: [
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TheyDiColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badgeLabel,
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.primary)),
              ),

              // Manage button for Attending
              if (badgeLabel == 'Attending') ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () =>
                      context.push(AppRoutes.eventAttendees, extra: event),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: TheyDiColors.divider,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Manage',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textSecondary)),
                  ),
                ),
              ],

              // Pending badge for Hosted-created events
              if ((badgeLabel == 'Created' || badgeLabel == 'Hosting') &&
                  event.pendingCount > 0) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () =>
                      context.push(AppRoutes.hostManage, extra: event.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${event.pendingCount} pending',
                        style: TheyDiTextStyles.caption.copyWith(
                            color: Colors.amber,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],

              if ((badgeLabel == 'Created' || badgeLabel == 'Hosting') &&
                  event.pendingCount == 0) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () =>
                      context.push(AppRoutes.hostManage, extra: event.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: TheyDiColors.divider,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Manage',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textSecondary)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
// EVENTS TAB WITH UPCOMING / PAST SECTIONS
// ══════════════════════════════════════
class _EventsTab extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String emptyEmoji;
  final String emptyUpcomingMessage;
  final String emptyPastMessage;
  final String badgeLabel;
  final String currentUid;
  final String roleLabel;

  const _EventsTab({
    required this.stream,
    required this.emptyEmoji,
    required this.emptyUpcomingMessage,
    required this.emptyPastMessage,
    required this.badgeLabel,
    required this.currentUid,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: TheyDiColors.primary));
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading events',
                  style: TheyDiTextStyles.bodySmall));
        }

        final docs = snapshot.data?.docs ?? [];
        final events = docs
            .map((d) => EventModel.fromFirestore(d))
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        final upcomingEvents = events.where((e) => !e.isCompleted).toList();
        final pastEvents = events.where((e) => e.isCompleted).toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(title: 'Upcoming Events'),
            if (upcomingEvents.isEmpty)
              _SectionEmpty(message: emptyUpcomingMessage)
            else ...upcomingEvents
                .map((event) => _ActiveEventCard(
                      event: event,
                      badgeLabel: badgeLabel,
                      currentUid: currentUid,
                    )
                        .animate(
                            delay: Duration(milliseconds: 80 * upcomingEvents.indexOf(event)))
                        .fade(duration: 300.ms)
                        .slideX(begin: 0.08, end: 0)),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Past Events'),
            if (pastEvents.isEmpty)
              _SectionEmpty(message: emptyPastMessage)
            else ...pastEvents
                .map((event) {
                  return _PastEventCard(
                    entry: _PastEventEntry(event: event, role: roleLabel),
                  )
                      .animate(
                          delay: Duration(milliseconds: 80 * pastEvents.indexOf(event)))
                      .fade(duration: 300.ms)
                      .slideX(begin: 0.08, end: 0);
                }),
          ],
        );
      },
    );
  }
}

// ── Data class for past event with role ──
class _PastEventEntry {
  final EventModel event;
  final String role; // 'Hosted' | 'Attended' | 'Requested'
  const _PastEventEntry({required this.event, required this.role});
}

// ── Section header for grouped lists ──
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: TheyDiTextStyles.headlineSmall
              .copyWith(color: TheyDiColors.textSecondary)),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  final String message;
  const _SectionEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Text(message, style: TheyDiTextStyles.bodySmall),
    );
  }
}

class _PastEventCard extends StatelessWidget {
  final _PastEventEntry entry;
  const _PastEventCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final event = entry.event;
    final isHosted = entry.role == 'Hosted';
    final isRequested = entry.role == 'Requested';
    final dateStr = DateFormat('EEE, MMM d • h:mm a').format(event.dateTime);
    final badgeLabel = isHosted
        ? '🟣 Hosted'
        : isRequested
            ? '⌛ Requested'
            : '🔵 Attended';
    final badgeColor = isHosted
        ? TheyDiColors.primary
        : isRequested
            ? Colors.orange
            : TheyDiColors.info;
    final badgeBackground = isHosted
        ? TheyDiColors.primary.withValues(alpha: 0.15)
        : isRequested
            ? Colors.orange.withValues(alpha: 0.15)
            : TheyDiColors.info.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Row(
        children: [
          // Category badge (greyed out = past)
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: TheyDiColors.textMuted.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                event.category.isNotEmpty ? event.category[0] : 'E',
                style: TheyDiTextStyles.displaySmall
                    .copyWith(color: TheyDiColors.textMuted),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: TheyDiTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(dateStr,
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textMuted)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 11, color: TheyDiColors.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text('${event.venue}, ${event.city}',
                          style: TheyDiTextStyles.caption
                              .copyWith(color: TheyDiColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.group_outlined,
                        size: 11, color: TheyDiColors.textMuted),
                    const SizedBox(width: 3),
                    Text('${event.currentAttendees} attended',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Role badge — Hosted, Requested, Attended
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeLabel,
                  style: TheyDiTextStyles.caption.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // View Summary button
              GestureDetector(
                onTap: () =>
                    context.push('/event/${event.id}', extra: event),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: TheyDiColors.divider,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('View',
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textSecondary)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final String emoji;
  final String message;
  const _EmptyState({required this.emoji, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(message, style: TheyDiTextStyles.headlineSmall),
          const SizedBox(height: 8),
          Text('Tap + to create one!', style: TheyDiTextStyles.bodySmall),
        ],
      ),
    );
  }
}
