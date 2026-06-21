// ─────────────────────────────────────────────────────────────────────────────
// CHANGES vs original profile_screen.dart
//
//  1. _ProfileContent: reads avgRating + totalReviews from the user doc
//  2. Hero Row: adds _RatingBadge widget below the avatar
//     (only shown when avgRating > 0)
//  3. All other sections (stat cards, social cards, menu items) unchanged
// ─────────────────────────────────────────────────────────────────────────────

// ── Drop-in replacement — paste full file ──
// Only the parts marked NEW are added; everything else is identical to the
// original profile_screen.dart you pasted earlier.

// Because profile_screen.dart is very long, this file contains ONLY the
// diff-relevant sections as clear inline comments so you can apply them:
//
// STEP 1 — In ProfileScreen.build() data: block, read two new fields:
//
//   final double avgRating = (data['avgRating'] as num?)?.toDouble() ?? 0.0;
//   final int totalReviews = (data['totalReviews'] as num?)?.toInt() ?? 0;
//
// STEP 2 — Pass them into _ProfileContent:
//
//   return _ProfileContent(
//     ...existing params...
//     avgRating: avgRating,       // ← NEW
//     totalReviews: totalReviews, // ← NEW
//   );
//
// STEP 3 — In _ProfileContent, add two new required fields:
//
//   final double avgRating;
//   final int totalReviews;
//
// STEP 4 — In _ProfileContent.build(), inside the Hero Row,
//   AFTER the avatar Container and BEFORE the Expanded(child: Column(...)),
//   add the _RatingBadge widget directly below the avatar:
//
//   Column(
//     children: [
//       Container(...),   // existing avatar
//       const SizedBox(height: 6),
//       if (avgRating > 0)
//         _RatingBadge(avgRating: avgRating, totalReviews: totalReviews),
//     ],
//   ),
//
// ─────────────────────────────────────────────────────────────────────────────
//
// The _RatingBadge widget to add at the bottom of the file:

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Small ⭐ badge shown below the profile avatar.
/// Only rendered when avgRating > 0.
class ProfileRatingBadge extends StatelessWidget {
  final double avgRating;
  final int totalReviews;

  const ProfileRatingBadge({
    super.key,
    required this.avgRating,
    required this.totalReviews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
          const SizedBox(width: 4),
          Text(
            avgRating.toStringAsFixed(1),
            style: TheyDiTextStyles.caption.copyWith(
              color: Colors.amber,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (totalReviews > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($totalReviews)',
              style: TheyDiTextStyles.caption.copyWith(
                color: Colors.amber.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}