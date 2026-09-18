import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../features/events/models/event_model.dart';
import '../../features/events/widgets/event_share_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EventCardCompact — horizontal card used in lists.
// UI: "Event" → "Experience" label; polished shadow, rounded corners.
// ─────────────────────────────────────────────────────────────────────────────
class EventCardCompact extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;

  const EventCardCompact({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d · h:mm a').format(event.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TheyDiColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              onTap ?? () => context.push('/event/${event.id}', extra: event),
          splashColor: TheyDiColors.primary.withValues(alpha: 0.08),
          highlightColor: TheyDiColors.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: event.allImages.isNotEmpty
                      ? Image.network(
                          event.allImages.first,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _CategoryPlaceholder(
                              category: event.category, size: 58),
                        )
                      : _CategoryPlaceholder(
                          category: event.category, size: 58),
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
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: TheyDiColors.textMuted),
                        const SizedBox(width: 4),
                        Flexible(
                            child: Text(dateStr,
                                style: TheyDiTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: TheyDiColors.textMuted),
                        const SizedBox(width: 4),
                        Flexible(
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

                // Right — price + spots + share menu
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _CardShareMenu(event: event),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: event.isFree
                            ? Colors.green.withValues(alpha: 0.15)
                            : TheyDiColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.isFree ? 'FREE' : '₹${event.price.toInt()}',
                        style: TheyDiTextStyles.caption.copyWith(
                          color: event.isFree
                              ? Colors.green
                              : TheyDiColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EventCardLarge — vertical featured card.
// UI: "Event" → "Experience" badge; taller image, polished shadow.
// ─────────────────────────────────────────────────────────────────────────────
class EventCardLarge extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;

  const EventCardLarge({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d · h:mm a').format(event.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TheyDiColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              onTap ?? () => context.push('/event/${event.id}', extra: event),
          splashColor: TheyDiColors.primary.withValues(alpha: 0.06),
          highlightColor: TheyDiColors.primary.withValues(alpha: 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Image area
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: event.allImages.isNotEmpty
                      ? Image.network(
                          event.allImages.first,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 140,
                            decoration: const BoxDecoration(
                                gradient: TheyDiColors.gradientPrimary),
                          ),
                        )
                      : Container(
                          height: 140,
                          decoration: const BoxDecoration(
                              gradient: TheyDiColors.gradientPrimary),
                        ),
                ),

                // Purpose + Category badge — top-left. Shows "Professional
                // · Tech" style when the experience has a purpose set;
                // falls back to just the category for older experiences
                // created before the purpose field existed.
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (event.purpose.isNotEmpty) ...[
                          Icon(
                            event.purpose == 'Professional'
                                ? Icons.work_outline
                                : Icons.celebration_outlined,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          event.purpose.isNotEmpty
                              ? '${event.purpose} · ${event.category}'
                              : event.category,
                          style: TheyDiTextStyles.caption
                              .copyWith(color: Colors.white),
                        ),
                      ],
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

                // Share menu — bottom-right of image
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _CardShareMenu(event: event, dark: true),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                        size: 13, color: TheyDiColors.textMuted),
                    const SizedBox(width: 5),
                    Flexible(
                        child: Text(dateStr,
                            style: TheyDiTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: TheyDiColors.textMuted),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${event.venue}, ${event.city}',
                        style: TheyDiTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.people_outline,
                            size: 14, color: TheyDiColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${event.spotsLeft} spots left',
                          style: TheyDiTextStyles.caption.copyWith(
                            color: event.spotsLeft < 5
                                ? TheyDiColors.error
                                : TheyDiColors.textMuted,
                          ),
                        ),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  TheyDiColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text('View Experience',
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryPlaceholder extends StatelessWidget {
  final String category;
  final double size;
  const _CategoryPlaceholder({required this.category, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(gradient: TheyDiColors.gradientPrimary),
      child: Center(
        child: Text(
          category.isNotEmpty ? category[0] : 'E',
          style: TheyDiTextStyles.displayMedium
              .copyWith(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}

class _CardShareMenu extends StatelessWidget {
  final EventModel event;
  final bool dark;
  const _CardShareMenu({required this.event, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: dark
                ? Colors.black.withValues(alpha: 0.45)
                : TheyDiColors.card,
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
              // Was white text on a white popup background (TheyDiColors.card
              // is #FFFFFF), which made this label invisible.
              Text('Share Experience',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: TheyDiColors.textPrimary)),
            ]),
          ),
        ],
        onSelected: (value) {
          if (value == 'share') showEventShareSheet(context, event: event);
        },
      ),
    );
  }
}