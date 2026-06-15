import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/booking_model.dart';

// Stream user's bookings from Firestore
final _bookingsProvider =
    StreamProvider.autoDispose<List<BookingModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('bookings')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .toList());
});

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_bookingsProvider);

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
                      icon:
                          const Icon(Icons.arrow_back, color: TheyDiColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text('Payment History',
                        style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 8),

              // Content
              Expanded(
                child: bookingsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: TheyDiColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('Failed to load: $e',
                          style: TheyDiTextStyles.bodySmall),
                    ),
                  ),
                  data: (bookings) {
                    if (bookings.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Calculate totals
                    final totalSpent = bookings
                        .where((b) => b.isConfirmed)
                        .fold(0.0, (sum, b) => sum + b.totalAmount);
                    final totalBookings =
                        bookings.where((b) => b.isConfirmed).length;

                    return Column(
                      children: [
                        // Stats row
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              _StatChip(
                                label: 'Total spent',
                                value:
                                    '₹${totalSpent.toStringAsFixed(0)}',
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                label: 'Bookings',
                                value: totalBookings.toString(),
                              ),
                            ],
                          ),
                        )
                            .animate(delay: 100.ms)
                            .fade(duration: 400.ms),

                        const SizedBox(height: 8),

                        // Transactions list
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20),
                            itemCount: bookings.length,
                            itemBuilder: (context, index) {
                              return _BookingCard(
                                      booking: bookings[index])
                                  .animate(
                                    delay: Duration(
                                        milliseconds:
                                            150 + 50 * index),
                                  )
                                  .fade(duration: 300.ms)
                                  .slideY(begin: 0.1, end: 0);
                            },
                          ),
                        ),
                      ],
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
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text('No transactions yet',
              style: TheyDiTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Your booking history will appear here',
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Stats chip ──
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: Column(
          children: [
            Text(value, style: TheyDiTextStyles.displayMedium),
            const SizedBox(height: 2),
            Text(label, style: TheyDiTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

// ── Booking card ──
class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('MMM d, yyyy · h:mm a').format(booking.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                child: Text(
                  booking.eventTitle,
                  style: TheyDiTextStyles.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(booking.status),
            ],
          ),
          const SizedBox(height: 8),

          // Date
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 13, color: TheyDiColors.textMuted),
              const SizedBox(width: 4),
              Text(dateStr, style: TheyDiTextStyles.caption),
            ],
          ),
          const SizedBox(height: 4),

          // Payment method + txn id
          Row(
            children: [
              const Icon(Icons.payment,
                  size: 13, color: TheyDiColors.textMuted),
              const SizedBox(width: 4),
              Text(booking.paymentMethod,
                  style: TheyDiTextStyles.caption),
              const Spacer(),
              if (booking.transactionId != null)
                Text(
                  booking.transactionId!.length > 16
                      ? '${booking.transactionId!.substring(0, 16)}...'
                      : booking.transactionId!,
                  style: TheyDiTextStyles.caption
                      .copyWith(color: TheyDiColors.textMuted),
                ),
            ],
          ),

          const SizedBox(height: 10),
          Container(height: 1, color: TheyDiColors.divider),
          const SizedBox(height: 10),

          // Amount breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ticket + fee',
                  style: TheyDiTextStyles.caption
                      .copyWith(color: TheyDiColors.textSecondary)),
              Text(
                '₹${booking.amount.toStringAsFixed(0)} + ₹${booking.platformFee.toStringAsFixed(0)}',
                style: TheyDiTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: TheyDiTextStyles.labelMedium),
              Text(
                '₹${booking.totalAmount.toStringAsFixed(0)}',
                style: TheyDiTextStyles.labelLarge.copyWith(
                  color: booking.isConfirmed
                      ? Colors.green
                      : TheyDiColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(BookingStatus status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case BookingStatus.confirmed:
        bgColor = Colors.green.withValues(alpha: 0.15);
        textColor = Colors.green;
        break;
      case BookingStatus.pending:
        bgColor = Colors.amber.withValues(alpha: 0.15);
        textColor = Colors.amber;
        break;
      case BookingStatus.cancelled:
        bgColor = Colors.red.withValues(alpha: 0.15);
        textColor = Colors.red;
        break;
      case BookingStatus.refunded:
        bgColor = Colors.blue.withValues(alpha: 0.15);
        textColor = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.name[0].toUpperCase() + status.name.substring(1),
        style: TheyDiTextStyles.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
