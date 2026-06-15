import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../events/models/booking_model.dart';
import '../../events/models/event_model.dart';

// Stream host's events
final _hostEventsProvider =
    StreamProvider.autoDispose<List<EventModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('events')
      .where('creatorUid', isEqualTo: uid)
      .orderBy('dateTime', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => EventModel.fromFirestore(d)).toList());
});

// Stream bookings for host's events
final _hostBookingsProvider =
    StreamProvider.autoDispose<List<BookingModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('bookings')
      .where('hostUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => BookingModel.fromFirestore(d)).toList());
});

class HostDashboardScreen extends ConsumerWidget {
  const HostDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_hostEventsProvider);
    final bookingsAsync = ref.watch(_hostBookingsProvider);

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
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: TheyDiColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text('Host Dashboard',
                        style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 16),

              Expanded(
                child: eventsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: TheyDiColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Text('Failed to load: $e',
                        style: TheyDiTextStyles.bodySmall),
                  ),
                  data: (events) {
                    return bookingsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: TheyDiColors.primary),
                      ),
                      error: (e, _) => Center(
                        child: Text('Failed to load: $e',
                            style: TheyDiTextStyles.bodySmall),
                      ),
                      data: (bookings) {
                        if (events.isEmpty) {
                          return _buildEmptyState();
                        }

                        return _DashboardContent(
                          events: events,
                          bookings: bookings,
                        );
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined,
              size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text('No events created yet',
              style: TheyDiTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Create your first event to see analytics here',
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final List<EventModel> events;
  final List<BookingModel> bookings;

  const _DashboardContent({
    required this.events,
    required this.bookings,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate stats
    final totalEvents = events.length;
    final totalAttendees =
        events.fold(0, (sum, e) => sum + e.attendeeUids.length);
    final confirmedBookings =
        bookings.where((b) => b.isConfirmed).toList();
    final totalRevenue =
        confirmedBookings.fold(0.0, (sum, b) => sum + b.amount);
    final platformFees =
        confirmedBookings.fold(0.0, (sum, b) => sum + b.platformFee);
    final netEarnings = totalRevenue - platformFees;

    // Upcoming vs past events
    final now = DateTime.now();
    final upcomingEvents =
        events.where((e) => e.dateTime.isAfter(now)).toList();
    final pastEvents =
        events.where((e) => e.dateTime.isBefore(now)).toList();

    // Average fill rate
    final totalCapacity =
        events.fold(0, (sum, e) => sum + e.maxAttendees);
    final fillRate = totalCapacity > 0
        ? (totalAttendees / totalCapacity * 100)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Revenue card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: TheyDiColors.gradientPrimary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total earnings',
                  style: TheyDiTextStyles.caption
                      .copyWith(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(
                '₹${netEarnings.toStringAsFixed(0)}',
                style: TheyDiTextStyles.displayLarge
                    .copyWith(color: Colors.white, fontSize: 36),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _miniStat('Revenue', '₹${totalRevenue.toStringAsFixed(0)}'),
                  const SizedBox(width: 20),
                  _miniStat('Platform fees', '₹${platformFees.toStringAsFixed(0)}'),
                ],
              ),
            ],
          ),
        ).animate(delay: 100.ms).fade(duration: 400.ms),

        const SizedBox(height: 16),

        // Stats grid
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.event,
                label: 'Total events',
                value: totalEvents.toString(),
                iconColor: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.people,
                label: 'Total attendees',
                value: totalAttendees.toString(),
                iconColor: Colors.green,
              ),
            ),
          ],
        ).animate(delay: 150.ms).fade(duration: 400.ms),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.confirmation_num,
                label: 'Bookings',
                value: confirmedBookings.length.toString(),
                iconColor: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.pie_chart_outline,
                label: 'Fill rate',
                value: '${fillRate.toStringAsFixed(0)}%',
                iconColor: Colors.amber,
              ),
            ),
          ],
        ).animate(delay: 200.ms).fade(duration: 400.ms),

        const SizedBox(height: 24),

        // Event performance
        Text('Event performance',
                style: TheyDiTextStyles.labelLarge)
            .animate(delay: 250.ms)
            .fade(duration: 300.ms),
        const SizedBox(height: 4),
        Text(
          '${upcomingEvents.length} upcoming · ${pastEvents.length} completed',
          style: TheyDiTextStyles.caption
              .copyWith(color: TheyDiColors.textSecondary),
        ).animate(delay: 280.ms).fade(duration: 300.ms),
        const SizedBox(height: 12),

        ...List.generate(events.length, (index) {
          final event = events[index];
          final isPast = event.dateTime.isBefore(now);
          final eventBookings = confirmedBookings
              .where((b) => b.eventId == event.id)
              .toList();
          final eventRevenue =
              eventBookings.fold(0.0, (sum, b) => sum + b.amount);

          return _EventPerformanceCard(
            event: event,
            isPast: isPast,
            bookingCount: eventBookings.length,
            revenue: eventRevenue,
          )
              .animate(
                  delay: Duration(milliseconds: 300 + 50 * index))
              .fade(duration: 300.ms)
              .slideY(begin: 0.1, end: 0);
        }),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TheyDiTextStyles.caption
                .copyWith(color: Colors.white60, fontSize: 11)),
        Text(value,
            style: TheyDiTextStyles.labelMedium
                .copyWith(color: Colors.white)),
      ],
    );
  }
}

// ── Stat Card ──
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value, style: TheyDiTextStyles.displayMedium),
          const SizedBox(height: 2),
          Text(label, style: TheyDiTextStyles.caption),
        ],
      ),
    );
  }
}

// ── Event Performance Card ──
class _EventPerformanceCard extends StatelessWidget {
  final EventModel event;
  final bool isPast;
  final int bookingCount;
  final double revenue;

  const _EventPerformanceCard({
    required this.event,
    required this.isPast,
    required this.bookingCount,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('MMM d, yyyy').format(event.dateTime);
    final fillPercent = event.maxAttendees > 0
        ? (event.attendeeUids.length / event.maxAttendees * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status
          Row(
            children: [
              Expanded(
                child: Text(event.title,
                    style: TheyDiTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPast
                      ? Colors.grey.withValues(alpha: 0.15)
                      : Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPast ? 'Completed' : 'Upcoming',
                  style: TheyDiTextStyles.caption.copyWith(
                    color: isPast ? Colors.grey : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(dateStr, style: TheyDiTextStyles.caption),
          const SizedBox(height: 10),

          // Fill bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fillPercent / 100,
                    backgroundColor: TheyDiColors.divider,
                    valueColor: AlwaysStoppedAnimation(
                      fillPercent > 80
                          ? Colors.green
                          : fillPercent > 50
                              ? Colors.amber
                              : TheyDiColors.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${event.attendeeUids.length}/${event.maxAttendees}',
                style: TheyDiTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stats row
          Row(
            children: [
              Icon(Icons.confirmation_num_outlined,
                  size: 13, color: TheyDiColors.textMuted),
              const SizedBox(width: 4),
              Text('$bookingCount bookings',
                  style: TheyDiTextStyles.caption),
              const SizedBox(width: 16),
              if (revenue > 0) ...[
                Icon(Icons.currency_rupee,
                    size: 13, color: TheyDiColors.textMuted),
                const SizedBox(width: 2),
                Text('₹${revenue.toStringAsFixed(0)}',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: Colors.green)),
              ],
              if (event.isFree)
                Text('Free event',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
