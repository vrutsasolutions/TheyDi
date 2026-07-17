import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../features/events/models/event_model.dart';
// ── NEW import ──
import '../../features/events/widgets/event_share_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Compact horizontal event card — reusable across screens.
// CHANGE: added ⋮ menu icon (top-right) with "Share Event" option.
// ─────────────────────────────────────────────────────────────────────────────
class EventCardCompact extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;

  const EventCardCompact({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d · h:mm a').format(event.dateTime);

    return GestureDetector(
      onTap: onTap ?? () => context.push('/event/${event.id}', extra: event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: Row(
          children: [
            // Category icon
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: event.allImages.isNotEmpty
                  ? Image.network(
                      event.allImages.first,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                        ),
                        child: Center(
                          child: Text(
                            event.category.isNotEmpty ? event.category[0] : 'E',
                            style: TheyDiTextStyles.displayMedium
                                .copyWith(color: Colors.white, fontSize: 20),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: TheyDiColors.gradientPrimary,
                      ),
                      child: Center(
                        child: Text(
                          event.category.isNotEmpty ? event.category[0] : 'E',
                          style: TheyDiTextStyles.displayMedium
                              .copyWith(color: Colors.white, fontSize: 20),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: TheyDiTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: TheyDiColors.textMuted),
                    const SizedBox(width: 4),
                    Text(dateStr, style: TheyDiTextStyles.caption),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 12, color: TheyDiColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${event.venue}, ${event.city}',
                        style: TheyDiTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Right side — price + spots + ⋮ menu
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ── NEW: 3-dot menu ──
                _CardShareMenu(event: event),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: event.isFree
                        ? Colors.green.withValues(alpha: 0.15)
                        : TheyDiColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.isFree ? 'FREE' : '₹${event.price.toInt()}',
                    style: TheyDiTextStyles.caption.copyWith(
                      color: event.isFree ? Colors.green : TheyDiColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${event.spotsLeft} left',
                  style: TheyDiTextStyles.caption.copyWith(
                    color: event.spotsLeft < 5
                        ? TheyDiColors.error
                        : TheyDiColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Large vertical event card — for featured/home feed.
// CHANGE: added ⋮ menu icon (top-right of image area) with "Share Event" option.
// ─────────────────────────────────────────────────────────────────────────────
class EventCardLarge extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;

  const EventCardLarge({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d · h:mm a').format(event.dateTime);

    return GestureDetector(
      onTap: onTap ?? () => context.push('/event/${event.id}', extra: event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area with badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: event.allImages.isNotEmpty
                      ? Image.network(
                          event.allImages.first,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            decoration: const BoxDecoration(
                              gradient: TheyDiColors.gradientPrimary,
                            ),
                          ),
                        )
                      : Container(
                          height: 120,
                          decoration: const BoxDecoration(
                            gradient: TheyDiColors.gradientPrimary,
                          ),
                        ),
                ),

                // Price badge — top-right
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: event.isFree ? Colors.green : TheyDiColors.dark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      event.isFree ? 'FREE' : '₹${event.price.toInt()}',
                      style: TheyDiTextStyles.labelMedium
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),

                // Category badge — top-left
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(event.category,
                        style: TheyDiTextStyles.caption
                            .copyWith(color: Colors.white)),
                  ),
                ),

                // ── NEW: 3-dot menu — bottom-right of image ──
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _CardShareMenu(event: event, dark: true),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: TheyDiTextStyles.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: TheyDiColors.textMuted),
                    const SizedBox(width: 4),
                    Text(dateStr, style: TheyDiTextStyles.caption),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: TheyDiColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${event.venue}, ${event.city}',
                        style: TheyDiTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.people_outline,
                            size: 14, color: TheyDiColors.textMuted),
                        const SizedBox(width: 4),
                        Text('${event.spotsLeft} spots left',
                            style: TheyDiTextStyles.caption.copyWith(
                              color: event.spotsLeft < 5
                                  ? TheyDiColors.error
                                  : TheyDiColors.textMuted,
                            )),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('View',
                            style: TheyDiTextStyles.labelMedium
                                .copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CardShareMenu — the ⋮ popup menu used on both card variants
// ─────────────────────────────────────────────────────────────────────────────
class _CardShareMenu extends StatelessWidget {
  final EventModel event;

  /// When true, uses a dark semi-transparent background (for image overlays).
  final bool dark;

  const _CardShareMenu({required this.event, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Stop tap propagating to parent card's onTap
      onTap: () {},
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color:
                dark ? Colors.black.withValues(alpha: 0.45) : TheyDiColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.15)
                  : TheyDiColors.divider,
              width: 1,
            ),
          ),
          child: Icon(
            Icons.more_vert,
            size: 18,
            color: dark ? Colors.white : TheyDiColors.textSecondary,
          ),
        ),
        color: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            value: 'share',
            child: Row(children: [
              const Icon(Icons.share_outlined,
                  size: 18, color: TheyDiColors.primary),
              const SizedBox(width: 10),
              Text('Share Event',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: Colors.white)),
            ]),
          ),
        ],
        onSelected: (value) {
          if (value == 'share') {
            showEventShareSheet(context, event: event);
          }
        },
      ),
    );
  }
}
