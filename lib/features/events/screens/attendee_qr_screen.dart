// ─────────────────────────────────────────────────────────────────────────────
// AttendeeQrScreen — Digital ticket with TheyDi-branded QR code
//
// Route args (via GoRouter extra map):
//   eventId   : String
//   bookingId : String
//   userId    : String
//
// On load:
//   1. Fetch event details (title, date, venue) from Firestore
//   2. Fetch attendee display name from Firestore
//   3. Call QrCheckInService.getOrCreateToken() → builds QR payload
//   4. Render branded ticket card with QR + event info
//
// File 9 in the QR Check-in series.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../services/qr_checkin_service.dart';

class AttendeeQrScreen extends StatefulWidget {
  final String eventId;
  final String bookingId;
  final String userId;

  const AttendeeQrScreen({
    super.key,
    required this.eventId,
    required this.bookingId,
    required this.userId,
  });

  @override
  State<AttendeeQrScreen> createState() => _AttendeeQrScreenState();
}

class _AttendeeQrScreenState extends State<AttendeeQrScreen> {
  bool _loading = true;
  String? _error;

  String _qrPayload = '';
  String _eventTitle = '';
  String _eventVenue = '';
  String _eventDate = '';
  String _eventTime = '';
  String _attendeeName = '';
  String _bookingRef = '';

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    try {
      final token = await QrCheckInService.getOrCreateToken(
        eventId: widget.eventId,
        bookingId: widget.bookingId,
        userId: widget.userId,
      );
      final payload = QrCheckInService.buildQrPayload(token);

      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      String title = 'Event';
      String venue = '';
      String date = '';
      String time = '';

      if (eventDoc.exists) {
        final d = eventDoc.data()!;
        title = d['title'] as String? ?? 'Event';
        venue = d['venue'] as String? ?? '';
        final city = d['city'] as String? ?? '';
        if (city.isNotEmpty && venue.isNotEmpty) venue = '$venue, $city';
        final ts = d['dateTime'];
        if (ts is Timestamp) {
          final dt = ts.toDate();
          date = DateFormat('EEE, MMM d, yyyy').format(dt);
          time = DateFormat('h:mm a').format(dt);
        }
      }

      String name = FirebaseAuth.instance.currentUser?.displayName ?? '';
      if (name.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        if (userDoc.exists) {
          final ud = userDoc.data()!;
          name = (ud['displayName'] as String? ??
              ud['fullName'] as String? ??
              ud['name'] as String? ??
              '');
        }
      }

      if (!mounted) return;
      setState(() {
        _qrPayload = payload;
        _eventTitle = title;
        _eventVenue = venue;
        _eventDate = date;
        _eventTime = time;
        _attendeeName = name.isNotEmpty ? name : 'Attendee';
        _bookingRef =
            widget.bookingId.length >= 8
                ? widget.bookingId
                    .substring(widget.bookingId.length - 8)
                    .toUpperCase()
                : widget.bookingId.toUpperCase();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: TheyDiColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('My Ticket', style: TheyDiTextStyles.displayMedium),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: TheyDiColors.primary))
          : _error != null
              ? _ErrorState(message: _error!, onRetry: () {
                  setState(() { _loading = true; _error = null; });
                  _loadTicket();
                })
              : _TicketView(
                  qrPayload: _qrPayload,
                  eventTitle: _eventTitle,
                  eventVenue: _eventVenue,
                  eventDate: _eventDate,
                  eventTime: _eventTime,
                  attendeeName: _attendeeName,
                  bookingRef: _bookingRef,
                ),
    );
  }
}

class _TicketView extends StatelessWidget {
  final String qrPayload;
  final String eventTitle;
  final String eventVenue;
  final String eventDate;
  final String eventTime;
  final String attendeeName;
  final String bookingRef;

  const _TicketView({
    required this.qrPayload,
    required this.eventTitle,
    required this.eventVenue,
    required this.eventDate,
    required this.eventTime,
    required this.attendeeName,
    required this.bookingRef,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(children: [
        _TicketCard(
          qrPayload: qrPayload,
          eventTitle: eventTitle,
          eventVenue: eventVenue,
          eventDate: eventDate,
          eventTime: eventTime,
          attendeeName: attendeeName,
          bookingRef: bookingRef,
        ).animate()
            .fade(duration: 400.ms)
            .slideY(begin: 0.06, end: 0, duration: 400.ms, curve: Curves.easeOut),
        const SizedBox(height: 24),
        _InfoBanner(
          icon: Icons.lightbulb_outline_rounded,
          message: 'For best scanning results, keep your screen at full brightness and hold it steady.',
        ).animate(delay: 200.ms).fade(duration: 300.ms),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Swipe down from the top to access brightness controls.'),
                backgroundColor: TheyDiColors.card,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ));
            },
            icon: const Icon(Icons.brightness_high_outlined, size: 18, color: TheyDiColors.primary),
            label: Text('Raise Screen Brightness',
                style: TheyDiTextStyles.labelMedium.copyWith(color: TheyDiColors.primary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: TheyDiColors.primary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ).animate(delay: 260.ms).fade(duration: 300.ms),
        const SizedBox(height: 32),
      ]),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final String qrPayload;
  final String eventTitle;
  final String eventVenue;
  final String eventDate;
  final String eventTime;
  final String attendeeName;
  final String bookingRef;

  const _TicketCard({
    required this.qrPayload, required this.eventTitle,
    required this.eventVenue, required this.eventDate,
    required this.eventTime, required this.attendeeName,
    required this.bookingRef,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: TheyDiColors.primary.withValues(alpha: 0.14),
          blurRadius: 24, offset: const Offset(0, 8),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.qr_code_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text('TheyDi · Digital Ticket',
                    style: TheyDiTextStyles.caption.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 14),
              Text(eventTitle,
                style: TheyDiTextStyles.displayMedium.copyWith(
                  color: Colors.white, fontSize: 20, height: 1.2),
                maxLines: 3, overflow: TextOverflow.ellipsis),
              if (eventVenue.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white70, size: 13),
                  const SizedBox(width: 4),
                  Expanded(child: Text(eventVenue,
                    style: TheyDiTextStyles.caption.copyWith(color: Colors.white70),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ]),
          ),

          // Notch tear line
          _NotchDivider(),

          // QR section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12, offset: const Offset(0, 2),
                  )],
                ),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  embeddedImage: const AssetImage('assets/images/logo.png'),
                  embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(36, 36)),
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: Color(0xFF4F46E5)),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A2E)),
                ),
              ),
              const SizedBox(height: 16),
              Text(attendeeName,
                style: TheyDiTextStyles.displayMedium.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Confirmed Attendee',
                style: TheyDiTextStyles.caption.copyWith(
                  color: TheyDiColors.primary, fontWeight: FontWeight.w600)),
            ]),
          ),

          if (eventDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _TicketInfoPill(icon: Icons.calendar_today_outlined, text: eventDate),
                const SizedBox(width: 8),
                _TicketInfoPill(icon: Icons.access_time_outlined, text: eventTime),
              ]),
            ),

          const SizedBox(height: 16),

          // Booking ref
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Booking Ref',
                style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textMuted)),
              Row(children: [
                Text('#$bookingRef',
                  style: TheyDiTextStyles.labelMedium.copyWith(
                    fontFamily: 'monospace', letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, size: 15, color: Colors.green),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _NotchDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Stack(alignment: Alignment.center, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(builder: (ctx, constraints) {
            const dashW = 6.0;
            const gapW = 5.0;
            final count = (constraints.maxWidth / (dashW + gapW)).floor();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(count, (_) =>
                  Container(width: dashW, height: 1, color: TheyDiColors.divider)),
            );
          }),
        ),
        Positioned(left: 0, child: Container(width: 18, height: 18,
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, shape: BoxShape.circle))),
        Positioned(right: 0, child: Container(width: 18, height: 18,
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, shape: BoxShape.circle))),
      ]),
    );
  }
}

class _TicketInfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TicketInfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: TheyDiColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 13, color: TheyDiColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(text,
            style: TheyDiTextStyles.caption.copyWith(
              color: TheyDiColors.textSecondary, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  const _InfoBanner({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TheyDiColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TheyDiColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: TheyDiColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
          style: TheyDiTextStyles.caption.copyWith(
            color: TheyDiColors.textSecondary, height: 1.5))),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: TheyDiColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.qr_code_2_rounded, size: 36, color: TheyDiColors.error),
          ),
          const SizedBox(height: 20),
          Text('Could not load ticket',
            style: TheyDiTextStyles.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message,
            style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textSecondary),
            textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
            width: 160, height: 46,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
              label: const Text('Try Again', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: TheyDiColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]),
      ),
    );
  }
}