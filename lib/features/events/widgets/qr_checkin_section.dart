// ─────────────────────────────────────────────────────────────────────────────
// QrCheckInSection — embedded card shown inside EventDetailScreen
//
// Shown only when enableQrCheckIn == true on the event.
//
//  Host view    → "Scan QR Codes" button → HostScannerScreen
//  Joined view  → "Show My QR Code" button → fetches bookingId → AttendeeQrScreen
//  Other states → informational chip (pending / not confirmed)
//
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../models/event_model.dart';

// Re-declare the same enum shape used in event_detail_screen so this widget
// can accept the booking state without a circular import.
// (Matches _BookingState in event_detail_screen.dart exactly.)
enum QrBookingState { none, pending, approvedAwaitPay, joined, rejected }

class QrCheckInSection extends StatefulWidget {
  final EventModel event;
  final bool isHost;

  /// Pass the _bookingState cast to [QrBookingState] — values align 1:1.
  final dynamic bookingState; // accepts _BookingState or QrBookingState

  final String currentUid;

  const QrCheckInSection({
    super.key,
    required this.event,
    required this.isHost,
    required this.bookingState,
    required this.currentUid,
  });

  @override
  State<QrCheckInSection> createState() => _QrCheckInSectionState();
}

class _QrCheckInSectionState extends State<QrCheckInSection> {
  bool _loading = false;

  // Whether this attendee's booking is confirmed (joined)
  bool get _isJoined {
    final bs = widget.bookingState;
    // Compare by name to avoid cross-file enum equality issues
    return bs.toString().contains('joined');
  }

  // ── Open Host Scanner ─────────────────────────────────────────────────────
  void _openHostScanner() {
    context.push(AppRoutes.hostScanner, extra: {
      'eventId': widget.event.id,
      'eventTitle': widget.event.title,
    });
  }

  // ── Fetch bookingId then open Attendee QR ─────────────────────────────────
  //
  // Strategy:
  //   1. Query bookings collection for userId + eventId (2-field query, no
  //      composite index needed). Filter status == 'confirmed' client-side.
  //   2. If confirmed booking found → navigate with real bookingId.
  //   3. If no booking found AND the event is free → the user joined via
  //      attendeeUids directly (no booking document is created for free events).
  //      Navigate with bookingId = '' so AttendeeQrScreen uses the free-event
  //      token path in QrCheckInService.
  //   4. If no booking found AND the event is paid → show specific error.
  //
  Future<void> _openAttendeeQr() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      // Guard: must have a valid UID
      if (widget.currentUid.isEmpty) {
        _showError('You must be signed in to view your QR code.');
        return;
      }

      // Step 1: Query bookings (2 fields only — avoids composite index)
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: widget.currentUid)
          .where('eventId', isEqualTo: widget.event.id)
          .limit(10)
          .get();

      if (!mounted) return;

      // Step 2: Filter confirmed bookings client-side
      final confirmedDocs = snap.docs
          .where((d) => d.data()['status'] == 'confirmed')
          .toList();

      if (confirmedDocs.isNotEmpty) {
        // Found a confirmed booking → paid event path
        final bookingId = confirmedDocs.first.id;
        context.push(AppRoutes.attendeeQr, extra: {
          'eventId': widget.event.id,
          'bookingId': bookingId,
          'userId': widget.currentUid,
        });
        return;
      }

      // Step 3: No confirmed booking found
      // If this is a FREE event, the user joined via attendeeUids array
      // (no booking document is created for free events). Navigate with
      // bookingId = '' — AttendeeQrScreen / QrCheckInService handles this.
      if (widget.event.isFree) {
        // Double-check: user must actually be in attendeeUids
        if (widget.event.attendeeUids.contains(widget.currentUid)) {
          context.push(AppRoutes.attendeeQr, extra: {
            'eventId': widget.event.id,
            'bookingId': '', // free event: no booking doc
            'userId': widget.currentUid,
          });
          return;
        } else {
          _showError('You have not joined this event yet.');
          return;
        }
      }

      // Step 4: Paid event but no confirmed booking — show specific message
      _showError('No confirmed booking found for this event. '
          'Complete your payment to get your ticket.');
    } catch (e) {
      if (!mounted) return;
      _showError('Error loading your ticket: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: TheyDiColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TheyDiColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: TheyDiColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: TheyDiColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.qr_code_scanner_outlined,
                color: TheyDiColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QR Check-in',
                  style: TheyDiTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Digital tickets enabled for this event',
                  style: TheyDiTextStyles.caption.copyWith(
                    color: TheyDiColors.textSecondary,
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 16),
          const Divider(color: TheyDiColors.divider, height: 1),
          const SizedBox(height: 16),

          // ── Action area ──────────────────────────────────────────────────
          if (widget.isHost) ...[
            // HOST: Scan Attendee QR button
            _QrActionButton(
              icon: Icons.qr_code_scanner_outlined,
              label: 'Scan Attendee QR Codes',
              subtitle: 'Open scanner to check in guests at the door',
              color: TheyDiColors.primary,
              loading: false,
              onTap: _openHostScanner,
            ),
          ] else if (_isJoined) ...[
            // CONFIRMED ATTENDEE: Show My QR Code button
            _QrActionButton(
              icon: Icons.qr_code_rounded,
              label: 'Show My QR Code',
              subtitle: 'Display your digital ticket at the entrance',
              color: const Color(0xFF6C63FF),
              loading: _loading,
              onTap: _openAttendeeQr,
            ),
          ] else ...[
            // PENDING / NOT YET JOINED: informational state
            _QrInfoChip(bookingState: widget.bookingState),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QrActionButton
// ─────────────────────────────────────────────────────────────────────────────

class _QrActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _QrActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QrInfoChip — shown when user hasn't confirmed their spot yet
// ─────────────────────────────────────────────────────────────────────────────

class _QrInfoChip extends StatelessWidget {
  final dynamic bookingState;
  const _QrInfoChip({required this.bookingState});

  @override
  Widget build(BuildContext context) {
    final isPending = bookingState.toString().contains('pending');
    final isAwaitPay = bookingState.toString().contains('approvedAwaitPay');

    String message;
    IconData icon;
    Color color;

    if (isPending) {
      message = 'Your QR code will be ready once the host approves your request.';
      icon = Icons.hourglass_top_rounded;
      color = Colors.amber;
    } else if (isAwaitPay) {
      message = 'Complete your payment to receive your unique QR ticket.';
      icon = Icons.payment_outlined;
      color = Colors.blue;
    } else {
      message = 'Join this event to get your personal QR check-in ticket.';
      icon = Icons.info_outline_rounded;
      color = TheyDiColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TheyDiTextStyles.caption.copyWith(
                color: TheyDiColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}