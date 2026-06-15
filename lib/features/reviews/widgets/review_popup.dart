import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:theydi/features/events/models/event_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Usage (from HomeScreen):
//
//   showReviewPopup(context, event: pendingEvent);
// ─────────────────────────────────────────────────────────────────────────────

void showReviewPopup(BuildContext context, {required EventModel event}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (_) => ReviewPopup(event: event),
  );
}

class ReviewPopup extends StatefulWidget {
  final EventModel event;
  const ReviewPopup({super.key, required this.event});

  @override
  State<ReviewPopup> createState() => _ReviewPopupState();
}

class _ReviewPopupState extends State<ReviewPopup> {
  double _hoveredStar = 0;
  double _selectedStar = 0;

  String get _ratingLabel {
    final star = _hoveredStar > 0 ? _hoveredStar : _selectedStar;
    if (star >= 5) return 'Amazing! 🤩';
    if (star >= 4) return 'Great! 😄';
    if (star >= 3) return 'Good 🙂';
    if (star >= 2) return 'Okay 😐';
    if (star >= 1) return 'Poor 😕';
    return 'Tap a star to rate';
  }

  void _goToFullReview() {
    Navigator.pop(context);
    context.push(AppRoutes.submitReview, extra: widget.event);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: TheyDiColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Confetti-style icon ──
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🎉', style: TextStyle(fontSize: 30)),
            ),
          )
              .animate()
              .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  duration: 400.ms,
                  curve: Curves.elasticOut),

          const SizedBox(height: 16),

          // ── Title ──
          Text(
            'How was your experience?',
            style: TheyDiTextStyles.displayMedium,
            textAlign: TextAlign.center,
          ).animate(delay: 100.ms).fade(duration: 300.ms),

          const SizedBox(height: 6),

          // ── Subtitle: event name + host ──
          Text(
            widget.event.title,
            style: TheyDiTextStyles.labelLarge
                .copyWith(color: TheyDiColors.primary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ).animate(delay: 130.ms).fade(duration: 300.ms),

          const SizedBox(height: 4),

          Text(
            'Conducted by ${widget.event.organizerName}',
            style: TheyDiTextStyles.caption
                .copyWith(color: TheyDiColors.textSecondary),
            textAlign: TextAlign.center,
          ).animate(delay: 150.ms).fade(duration: 300.ms),

          const SizedBox(height: 24),

          // ── Rating label ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _ratingLabel,
              key: ValueKey(_ratingLabel),
              style: TheyDiTextStyles.headlineMedium.copyWith(
                color: _selectedStar > 0 || _hoveredStar > 0
                    ? Colors.amber
                    : TheyDiColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate(delay: 170.ms).fade(duration: 300.ms),

          const SizedBox(height: 12),

          // ── Stars ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1.0;
              final isFilled = starValue <=
                  (_hoveredStar > 0 ? _hoveredStar : _selectedStar);
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedStar = starValue);
                  // Short delay then open full review screen
                  Future.delayed(const Duration(milliseconds: 300),
                      _goToFullReview);
                },
                child: MouseRegion(
                  onEnter: (_) =>
                      setState(() => _hoveredStar = starValue),
                  onExit: (_) => setState(() => _hoveredStar = 0),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      isFilled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: isFilled ? Colors.amber : TheyDiColors.textMuted,
                      size: 52,
                    )
                        .animate(
                            target: isFilled ? 1 : 0,
                            delay: Duration(
                                milliseconds: 200 + index * 40))
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1, 1),
                          duration: 200.ms,
                        ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // ── CTA: Write Review ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF4466), Color(0xFFAA44FF)]),
              ),
              child: ElevatedButton(
                onPressed: _goToFullReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Write a Review ✍️',
                  style: TheyDiTextStyles.labelLarge
                      .copyWith(color: Colors.white),
                ),
              ),
            ),
          ).animate(delay: 220.ms).fade(duration: 300.ms),

          const SizedBox(height: 12),

          // ── Skip ──
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe later',
              style: TheyDiTextStyles.labelMedium
                  .copyWith(color: TheyDiColors.textSecondary),
            ),
          ).animate(delay: 240.ms).fade(duration: 300.ms),
        ],
      ),
    );
  }
}
