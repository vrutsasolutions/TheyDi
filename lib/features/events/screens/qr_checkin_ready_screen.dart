// ─────────────────────────────────────────────────────────────────────────────
// QrCheckInReadyScreen
//
// Shown to the HOST immediately after creating an event with QR Check-in
// enabled.  Presents three action cards:
//   1. Scan Attendee QR  → navigates to HostScannerScreen
//   2. View Event QR     → navigates to EventQrScreen (promotional poster QR)
//   3. Share Event QR    → native share sheet with event deep-link
//
// After the host is done here they can tap "Continue" to reach
// CreateCircleScreen (same flow as without QR check-in).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      onTap: () => _showEventQrDialog(context),
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
                      onTap: () => _shareEvent(context),
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

  // ── Event QR dialog (promotional QR with deep-link) ───────────────────────
  void _showEventQrDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TheyDiColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TheyDiColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Event QR Code',
                style: TheyDiTextStyles.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Share this QR so people can discover your event',
                style: TheyDiTextStyles.bodySmall
                    .copyWith(color: TheyDiColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Placeholder — actual QR rendered in attendee_qr_screen.dart
              // For now show a stylised container so the sheet looks right.
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TheyDiColors.divider, width: 2),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_rounded,
                          size: 80, color: TheyDiColors.primary),
                      const SizedBox(height: 8),
                      Text(
                        'theydi.app/event/$eventId',
                        style: TheyDiTextStyles.caption.copyWith(
                          color: TheyDiColors.textMuted,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _shareEvent(context);
                  },
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share Event Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TheyDiColors.primary,
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

  // ── Share event deep-link ─────────────────────────────────────────────────
  void _shareEvent(BuildContext context) {
    // We use a simple SnackBar here; in production wire up share_plus
    // or url_launcher to share the deep-link below.
    // final link = 'https://theydi.app/event/$eventId';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.link, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'theydi.app/event/$eventId — share this with your guests!',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ]),
        backgroundColor: TheyDiColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
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