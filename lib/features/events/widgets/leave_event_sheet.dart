import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_theme.dart';
import '../services/leave_event_service.dart';
import 'package:theydi/features/events/models/event_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Usage (from AttendeesScreen):
//
//   showLeaveEventSheet(
//     context,
//     event: widget.event,
//     onLeft: () { /* refresh UI */ },
//   );
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showLeaveEventSheet(
  BuildContext context, {
  required EventModel event,
  required VoidCallback onLeft,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LeaveEventSheet(event: event, onLeft: onLeft),
  );
}

class LeaveEventSheet extends StatefulWidget {
  final EventModel event;
  final VoidCallback onLeft;

  const LeaveEventSheet({
    super.key,
    required this.event,
    required this.onLeft,
  });

  @override
  State<LeaveEventSheet> createState() => _LeaveEventSheetState();
}

class _LeaveEventSheetState extends State<LeaveEventSheet> {
  bool _leaving = false;

  double get _refundAmount => widget.event.price * 0.50;
  bool get _isPaid => !widget.event.isFree && widget.event.price > 0;
  bool get _hasStarted => widget.event.isOngoing || widget.event.isCompleted;

  Future<void> _confirmLeave() async {
    setState(() => _leaving = true);

    final result = await LeaveEventService.leaveEvent(
      eventId: widget.event.id,
      isFree: widget.event.isFree,
      price: widget.event.price,
    );

    if (!mounted) return;
    Navigator.pop(context); // close sheet

    if (result.success) {
      widget.onLeft();

      if (result.refundInitiated) {
        // Show refund success snackbar for paid events
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Left event. ₹${result.refundAmount.toStringAsFixed(0)} refund '
                  'will arrive in 7 working days.',
                ),
              ),
            ]),
            backgroundColor: TheyDiColors.card,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text('Successfully left event 🚪'),
            ]),
            backgroundColor: TheyDiColors.card,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: TheyDiColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header ──
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.exit_to_app,
                  color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Leave Event',
                    style: TheyDiTextStyles.displayMedium),
                Text(widget.event.title,
                    style: TheyDiTextStyles.caption.copyWith(
                        color: TheyDiColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]).animate().fade(duration: 250.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: 20),

          // ── Event has started warning ──
          if (_hasStarted) ...[
            _WarningBanner(
              icon: Icons.warning_amber_rounded,
              color: Colors.orange,
              message: 'This event has already started. '
                  'Leaving now may affect your trust score more.',
            ).animate(delay: 60.ms).fade(duration: 300.ms),
            const SizedBox(height: 14),
          ],

          // ── Free event warning ──
          if (!_isPaid && !_hasStarted) ...[
            _WarningBanner(
              icon: Icons.shield_outlined,
              color: Colors.amber,
              message: 'Leaving this free event will reduce your '
                  'TieIn trust score by 2 points. Frequent cancellations '
                  'may limit your ability to join future events.',
            ).animate(delay: 60.ms).fade(duration: 300.ms),
            const SizedBox(height: 14),
          ],

          // ── Paid event refund info ──
          if (_isPaid) ...[
            _RefundInfoCard(
              originalAmount: widget.event.price,
              refundAmount: _refundAmount,
            ).animate(delay: 60.ms).fade(duration: 300.ms),
            const SizedBox(height: 14),
            _WarningBanner(
              icon: Icons.shield_outlined,
              color: Colors.amber,
              message: 'Leaving will also reduce your trust score by 2 points.',
            ).animate(delay: 80.ms).fade(duration: 300.ms),
            const SizedBox(height: 14),
          ],

          // ── Confirm question ──
          Text(
            'Are you sure you want to leave "${widget.event.title}"?',
            style: TheyDiTextStyles.bodyMedium
                .copyWith(color: TheyDiColors.textSecondary, height: 1.5),
          ).animate(delay: 100.ms).fade(duration: 300.ms),

          const SizedBox(height: 24),

          // ── Action buttons ──
          Row(children: [
            // Cancel (keep spot)
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _leaving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: TheyDiColors.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Keep My Spot',
                    style: TheyDiTextStyles.labelMedium
                        .copyWith(color: TheyDiColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            // Leave (destructive)
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _leaving ? null : _confirmLeave,
                  icon: _leaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.exit_to_app,
                          color: Colors.white, size: 16),
                  label: Text(
                    _leaving ? 'Leaving...' : 'Leave Event',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ]).animate(delay: 120.ms).fade(duration: 300.ms),
        ],
      ),
    );
  }
}

// ── Refund info card ──────────────────────────────────────────────────────────
class _RefundInfoCard extends StatelessWidget {
  final double originalAmount;
  final double refundAmount;

  const _RefundInfoCard({
    required this.originalAmount,
    required this.refundAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.currency_rupee, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text('Refund Policy',
              style: TheyDiTextStyles.labelMedium
                  .copyWith(color: Colors.green)),
        ]),
        const SizedBox(height: 12),
        _RefundRow(
          label: 'Amount paid',
          value: '₹${originalAmount.toStringAsFixed(0)}',
          color: TheyDiColors.textSecondary,
        ),
        const SizedBox(height: 6),
        _RefundRow(
          label: 'Refund (50%)',
          value: '₹${refundAmount.toStringAsFixed(0)}',
          color: Colors.green,
          bold: true,
        ),
        const SizedBox(height: 10),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.access_time_outlined,
                size: 14, color: Colors.green),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Refund will be credited within 7 working days to your original payment method.',
                style: TheyDiTextStyles.caption.copyWith(
                    color: Colors.green, height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _RefundRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _RefundRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: TheyDiTextStyles.bodySmall
              .copyWith(color: TheyDiColors.textSecondary)),
      Text(value,
          style: TheyDiTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight:
                  bold ? FontWeight.w700 : FontWeight.w500)),
    ]);
  }
}

// ── Warning banner ────────────────────────────────────────────────────────────
class _WarningBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _WarningBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: TheyDiTextStyles.caption
                  .copyWith(color: color, height: 1.5)),
        ),
      ]),
    );
  }
}
