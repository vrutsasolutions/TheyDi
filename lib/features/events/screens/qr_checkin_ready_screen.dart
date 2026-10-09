// ─────────────────────────────────────────────────────────────────────────────
// QrCheckInReadyScreen
//
// Shown to the HOST immediately after creating an event with QR Check-in
// enabled.  Presents three action cards:
//   1. Scan Attendee QR  → navigates to HostScannerScreen
//   2. View Event QR     → bottom sheet with a REAL QrImageView (discovery QR)
//   3. Share Event QR    → full share sheet (copy link, native share, WhatsApp,
//                          download QR image, share to TheyDi in-app messages)
//
// HOST EVENT QR  ≠  ATTENDEE TICKET QR
//   • This screen's QR encodes the public deep-link:
//       https://theydi.app/event/<eventId>
//     — it is a *discovery* QR that lets anyone find the event.
//   • The attendee's personal ticket QR (AttendeeQrScreen) encodes:
//       theydi:checkin:<32-hex-token>
//     — it is unique per attendee and used for check-in.
//
// After the host is done here they can tap "Continue" to reach
// CreateCircleScreen (same flow as without QR check-in).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../inbox/circles/screens/create_circle_screen.dart';

class QrCheckInReadyScreen extends StatelessWidget {
  final String eventId;
  final String eventTitle;

  const QrCheckInReadyScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  // ── Deep-link URL for this event ──────────────────────────────────────────
  String get _eventUrl => 'https://theydi.app/event/$eventId';

  // ── Navigate to CreateCircleScreen (same post-creation flow) ─────────────
  void _goToCreateCircle(BuildContext context) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => CreateCircleScreen(
        linkedEventId: eventId,
        linkedEventTitle: eventTitle,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TheyDiColors.card,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: TheyDiColors.textPrimary,
                  onPressed: () => _goToCreateCircle(context),
                ),
                Expanded(
                  child: Text(
                    'QR Check-in Ready',
                    style: TheyDiTextStyles.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 40),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero card ─────────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            TheyDiColors.primary,
                            TheyDiColors.primary.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: TheyDiColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.qr_code_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your event is ready! 🎉',
                            style: TheyDiTextStyles.headlineMedium.copyWith(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'QR Check-in is enabled. Speed up attendee entry with digital tickets — no paper, no hassle.',
                            style: TheyDiTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_outlined,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    eventTitle,
                                    style: TheyDiTextStyles.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 400.ms).slideY(
                          begin: 0.08,
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        ),

                    const SizedBox(height: 28),

                    Text(
                      'What would you like to do?',
                      style: TheyDiTextStyles.labelMedium
                          .copyWith(color: TheyDiColors.textSecondary),
                    ).animate(delay: 100.ms).fade(duration: 300.ms),

                    const SizedBox(height: 12),

                    // ── Action card 1: Scan Attendee QR ──────────────────────
                    _ActionCard(
                      icon: Icons.qr_code_scanner_outlined,
                      iconColor: TheyDiColors.primary,
                      title: 'Scan Attendee QR',
                      subtitle:
                          'Open the host scanner to check in attendees at the door',
                      delay: 150,
                      onTap: () => context.push(
                        AppRoutes.hostScanner,
                        extra: {
                          'eventId': eventId,
                          'eventTitle': eventTitle,
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Action card 2: View Event QR ──────────────────────────
                    _ActionCard(
                      icon: Icons.qr_code_2_outlined,
                      iconColor: const Color(0xFF6C63FF),
                      title: 'View Event QR',
                      subtitle:
                          'Display a QR code attendees can scan to find your event',
                      delay: 200,
                      onTap: () => _showEventQrSheet(context),
                    ),

                    const SizedBox(height: 12),

                    // ── Action card 3: Share Event QR ─────────────────────────
                    _ActionCard(
                      icon: Icons.share_outlined,
                      iconColor: const Color(0xFF00B894),
                      title: 'Share Event QR',
                      subtitle:
                          'Share your event link with friends, circles or social media',
                      delay: 250,
                      onTap: () => _showShareSheet(context),
                    ),

                    const SizedBox(height: 32),

                    // ── Tip ───────────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TheyDiColors.inputFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TheyDiColors.divider),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              size: 18, color: TheyDiColors.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tip: Each attendee gets their own unique QR code automatically once their booking is confirmed. You\'ll see live check-in counts in the Host Scanner.',
                              style: TheyDiTextStyles.caption.copyWith(
                                color: TheyDiColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 300.ms).fade(duration: 300.ms),

                    const SizedBox(height: 32),

                    // ── Continue button ───────────────────────────────────────
                    GradientButton(
                      label: 'Continue — Create Circle',
                      onPressed: () => _goToCreateCircle(context),
                    ).animate(delay: 350.ms).fade(duration: 300.ms),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => _goToCreateCircle(context),
                        child: Text(
                          'Skip for now',
                          style: TheyDiTextStyles.bodySmall.copyWith(
                            color: TheyDiColors.textSecondary,
                          ),
                        ),
                      ),
                    ).animate(delay: 380.ms).fade(duration: 300.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Event QR bottom sheet — REAL QrImageView ──────────────────────────────
  void _showEventQrSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TheyDiColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TheyDiColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Event QR Code', style: TheyDiTextStyles.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'Share this QR so anyone can discover your event',
                style: TheyDiTextStyles.bodySmall
                    .copyWith(color: TheyDiColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Distinction note
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'This is a discovery QR — different from attendee check-in tickets.',
                        style: TheyDiTextStyles.caption.copyWith(
                            color: const Color(0xFF6C63FF)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Real QR code ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: TheyDiColors.primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _eventUrl,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF6C63FF),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // URL label
              Text(
                'theydi.app/event/$eventId',
                style: TheyDiTextStyles.caption.copyWith(
                  color: TheyDiColors.textMuted,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Share button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showShareSheet(context);
                  },
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share Event Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Full share sheet ──────────────────────────────────────────────────────
  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TheyDiColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ShareSheet(
        eventUrl: _eventUrl,
        eventTitle: eventTitle,
        eventId: eventId,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShareSheet — full sharing options
// ─────────────────────────────────────────────────────────────────────────────

class _ShareSheet extends StatelessWidget {
  final String eventUrl;
  final String eventTitle;
  final String eventId;

  const _ShareSheet({
    required this.eventUrl,
    required this.eventTitle,
    required this.eventId,
  });

  // Copy event link to clipboard
  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: eventUrl));
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Event link copied!',
              style: TextStyle(color: Colors.white)),
        ]),
        backgroundColor: TheyDiColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Native share sheet (works on Android + iOS; on web falls back gracefully)
  Future<void> _nativeShare(BuildContext context) async {
    Navigator.pop(context);
    await Share.share(
      'Join me at $eventTitle 🎉\n\n$eventUrl',
      subject: 'Check out $eventTitle on TheyDi!',
    );
  }

  // WhatsApp share
  Future<void> _shareWhatsApp(BuildContext context) async {
    final message = Uri.encodeComponent(
        'Join me at $eventTitle 🎉\n$eventUrl');
    final waUrl = Uri.parse('https://wa.me/?text=$message');
    Navigator.pop(context);
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } else {
      // WhatsApp not installed — fall back to native share
      await Share.share('Join me at $eventTitle 🎉\n\n$eventUrl');
    }
  }

  // Instagram / Twitter / other social — just launch system share
  Future<void> _shareOther(BuildContext context) async {
    Navigator.pop(context);
    await Share.share(
      'Join me at $eventTitle 🎉\n\n$eventUrl',
      subject: 'Check out $eventTitle on TheyDi!',
    );
  }

  // Download / save QR image — uses QrPainter.toImageData (qr_flutter 4.x API)
  Future<void> _downloadQr(BuildContext context) async {
    Navigator.pop(context);
    try {
      final painter = QrPainter(
        data: eventUrl,
        version: QrVersions.auto,
        gapless: true,
        // In qr_flutter 4.x, QrPainter uses QrEyeStyle / QrDataModuleStyle
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF6C63FF),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF1A1A2E),
        ),
      );

      // toImageData returns Future<ByteData?> in qr_flutter 4.x
      final byteData = await painter.toImageData(512);
      if (byteData == null) throw Exception('Could not render QR');

      final bytes = Uint8List.view(byteData.buffer);
      final xFile = XFile.fromData(
        bytes,
        name: 'theydi_event_$eventId.png',
        mimeType: 'image/png',
      );
      await Share.shareXFiles(
        [xFile],
        text: 'QR code for $eventTitle on TheyDi\n$eventUrl',
      );
    } catch (e) {
      // Fallback: share the link text if image render fails
      await Share.share(
        'Join $eventTitle on TheyDi 🎉\n$eventUrl',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TheyDiColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Share Your Event', style: TheyDiTextStyles.headlineMedium),
            const SizedBox(height: 6),
            Text(
              eventTitle,
              style: TheyDiTextStyles.bodySmall
                  .copyWith(color: TheyDiColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // ── Share options grid ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ShareOptionChip(
                  icon: Icons.link_rounded,
                  label: 'Copy Link',
                  color: TheyDiColors.primary,
                  onTap: () => _copyLink(context),
                ),
                _ShareOptionChip(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  color: const Color(0xFF00B894),
                  onTap: () => _nativeShare(context),
                ),
                _ShareOptionChip(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () => _shareWhatsApp(context),
                ),
                _ShareOptionChip(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  color: const Color(0xFF6C63FF),
                  onTap: () => _shareOther(context),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Download QR as image
            _ShareOptionTile(
              icon: Icons.qr_code_2_rounded,
              iconColor: const Color(0xFF6C63FF),
              title: 'Download QR Image',
              subtitle: 'Save QR as PNG to share on posters, social posts',
              onTap: () => _downloadQr(context),
            ),

            const SizedBox(height: 8),

            // Share to TheyDi in-app messages
            _ShareOptionTile(
              icon: Icons.forum_rounded,
              iconColor: TheyDiColors.primary,
              title: 'Share to TheyDi Messages',
              subtitle: 'Send event link to a friend or circle in the app',
              onTap: () {
                Navigator.pop(context);
                // Navigate to the messages/chat picker
                // The link will be pre-filled
                _shareViaInAppMessages(context);
              },
            ),

            const SizedBox(height: 12),

            // Event link preview chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: TheyDiColors.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TheyDiColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link,
                      size: 16, color: TheyDiColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      eventUrl,
                      style: TheyDiTextStyles.caption.copyWith(
                          color: TheyDiColors.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _copyLink(context),
                    child: const Icon(Icons.copy_rounded,
                        size: 16, color: TheyDiColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Share via in-app messages — open chat list with prefilled message
  void _shareViaInAppMessages(BuildContext context) {
    // Navigate to the chats screen; chat screen deep-links can pre-fill
    // the message draft. For now we show a snackbar guiding the host.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.forum_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Open any chat and paste the event link to share with friends.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ]),
        backgroundColor: TheyDiColors.primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Copy',
          textColor: Colors.white,
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: eventUrl)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShareOptionChip — circular icon + label (top row in share sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _ShareOptionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOptionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TheyDiTextStyles.caption.copyWith(
              color: TheyDiColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShareOptionTile — list-row style share option
// ─────────────────────────────────────────────────────────────────────────────

class _ShareOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TheyDiColors.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TheyDiTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textSecondary),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: TheyDiColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionCard
// ─────────────────────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int delay;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TheyDiColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TheyDiTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TheyDiTextStyles.caption.copyWith(
                      color: TheyDiColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                size: 20, color: TheyDiColors.textMuted),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fade(duration: 300.ms)
        .slideX(begin: 0.05, duration: 300.ms, curve: Curves.easeOut);
  }
}