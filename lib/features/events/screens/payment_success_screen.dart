import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String eventTitle;
  final double amount;
  final String transactionId;
  final DateTime dateTime;
  final String venue;

  const PaymentSuccessScreen({
    super.key,
    required this.eventTitle,
    required this.amount,
    required this.transactionId,
    required this.dateTime,
    required this.venue,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d · h:mm a').format(dateTime);

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Success checkmark
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(alpha: 0.15),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.green,
                    size: 48,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.3, 0.3),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    )
                    .fade(duration: 300.ms),

                const SizedBox(height: 24),

                Text('Booking confirmed!',
                        style: TheyDiTextStyles.displayMedium)
                    .animate(delay: 200.ms)
                    .fade(duration: 400.ms),

                const SizedBox(height: 8),

                Text(
                  'You\'re all set for this event',
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textSecondary),
                ).animate(delay: 300.ms).fade(duration: 300.ms),

                const SizedBox(height: 32),

                // Booking details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: TheyDiColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TheyDiColors.divider),
                  ),
                  child: Column(
                    children: [
                      // Event name
                      Text(
                        eventTitle,
                        style: TheyDiTextStyles.headlineMedium,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),

                      _detailRow(Icons.calendar_today_outlined, dateStr),
                      const SizedBox(height: 10),
                      _detailRow(Icons.location_on_outlined, venue),
                      const SizedBox(height: 10),
                      _detailRow(Icons.receipt_outlined, transactionId),

                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        color: TheyDiColors.divider,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount paid',
                              style: TheyDiTextStyles.bodySmall
                                  .copyWith(color: TheyDiColors.textSecondary)),
                          Text(
                            '₹${amount.toStringAsFixed(0)}',
                            style: TheyDiTextStyles.displayMedium.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
                    .animate(delay: 400.ms)
                    .fade(duration: 400.ms)
                    .slideY(begin: 0.15, end: 0),

                const Spacer(flex: 3),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: TheyDiColors.gradientPrimary,
                    ),
                    child: ElevatedButton(
                      onPressed: () => context.go(AppRoutes.myEvents),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'View My Events',
                        style: TheyDiTextStyles.labelLarge
                            .copyWith(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ).animate(delay: 550.ms).fade(duration: 300.ms),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => context.go(AppRoutes.home),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: TheyDiColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Back to Home',
                      style: TheyDiTextStyles.labelMedium
                          .copyWith(color: TheyDiColors.textSecondary),
                    ),
                  ),
                ).animate(delay: 600.ms).fade(duration: 300.ms),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: TheyDiColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TheyDiTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
