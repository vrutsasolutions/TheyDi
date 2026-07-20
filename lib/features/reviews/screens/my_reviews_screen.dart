import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/review_model.dart';

// Reviews received (as host)
final _receivedReviewsProvider =
    StreamProvider.autoDispose<List<ReviewModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('reviews')
      .where('hostUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => ReviewModel.fromFirestore(d)).toList());
});

// Reviews given (as attendee)
final _givenReviewsProvider =
    StreamProvider.autoDispose<List<ReviewModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('reviews')
      .where('reviewerUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => ReviewModel.fromFirestore(d)).toList());
});

class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [TheyDiColors.cardLight, TheyDiColors.surface],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: TheyDiColors.textPrimary),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 4),
                      Text('My Reviews', style: TheyDiTextStyles.displayMedium),
                    ],
                  ),
                ).animate().fade(duration: 300.ms),

                const SizedBox(height: 12),

                // Rating summary
                _RatingSummary(),

                const SizedBox(height: 8),

                // Tabs
                TabBar(
                  indicatorColor: TheyDiColors.primary,
                  labelColor: TheyDiColors.textPrimary,
                  unselectedLabelColor: TheyDiColors.textPrimary,
                  labelStyle: TheyDiTextStyles.labelMedium,
                  tabs: const [
                    Tab(text: 'Received'),
                    Tab(text: 'Given'),
                  ],
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    children: [
                      _ReviewList(
                          provider: _receivedReviewsProvider,
                          emptyMessage: 'No reviews received yet',
                          emptySubtitle:
                              'Host events to get reviews from attendees'),
                      _ReviewList(
                          provider: _givenReviewsProvider,
                          emptyMessage: 'No reviews given yet',
                          emptySubtitle:
                              'Attend events and share your feedback'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Rating Summary Card ──
class _RatingSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivedAsync = ref.watch(_receivedReviewsProvider);

    return receivedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (reviews) {
        if (reviews.isEmpty) return const SizedBox.shrink();

        double totalRating = 0;
        for (final r in reviews) {
          totalRating += r.rating;
        }
        final avgRating = totalRating / reviews.length;

        // Count per star
        final starCounts = List.filled(5, 0);
        for (final r in reviews) {
          final idx = r.rating.round() - 1;
          if (idx >= 0 && idx < 5) starCounts[idx]++;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TheyDiColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TheyDiColors.divider),
            ),
            child: Row(
              children: [
                // Average rating
                Column(
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style:
                          TheyDiTextStyles.displayLarge.copyWith(fontSize: 36),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        return Icon(
                          i < avgRating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                      style: TheyDiTextStyles.caption,
                    ),
                  ],
                ),

                const SizedBox(width: 24),

                // Star breakdown bars
                Expanded(
                  child: Column(
                    children: List.generate(5, (i) {
                      final star = 5 - i;
                      final count = starCounts[star - 1];
                      final fraction =
                          reviews.isNotEmpty ? count / reviews.length : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('$star', style: TheyDiTextStyles.caption),
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded,
                                size: 12, color: Colors.amber),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  backgroundColor: TheyDiColors.divider,
                                  valueColor: const AlwaysStoppedAnimation(
                                      Colors.amber),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 20,
                              child: Text(
                                '$count',
                                style: TheyDiTextStyles.caption,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ).animate(delay: 100.ms).fade(duration: 400.ms);
      },
    );
  }
}

// ── Review List ──
class _ReviewList extends ConsumerWidget {
  final StreamProvider<List<ReviewModel>> provider;
  final String emptyMessage;
  final String emptySubtitle;

  const _ReviewList({
    required this.provider,
    required this.emptyMessage,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(provider);

    return reviewsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: TheyDiColors.primary),
      ),
      error: (e, _) => Center(
        child: Text('Failed to load: $e', style: TheyDiTextStyles.bodySmall),
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.rate_review_outlined,
                    size: 64, color: Colors.grey[700]),
                const SizedBox(height: 16),
                Text(emptyMessage, style: TheyDiTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Text(emptySubtitle,
                    style: TheyDiTextStyles.bodySmall
                        .copyWith(color: TheyDiColors.textSecondary),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            return _ReviewCard(review: reviews[index])
                .animate(delay: Duration(milliseconds: 50 * index))
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, end: 0);
          },
        );
      },
    );
  }
}

// ── Review Card ──
class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(review.createdAt);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isReceived = review.hostUid == uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: name + stars
          Row(
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: TheyDiColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isReceived
                        ? (review.reviewerName.isNotEmpty
                            ? review.reviewerName[0].toUpperCase()
                            : '?')
                        : (review.hostName.isNotEmpty
                            ? review.hostName[0].toUpperCase()
                            : '?'),
                    style: TheyDiTextStyles.labelLarge
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReceived ? review.reviewerName : review.hostName,
                      style: TheyDiTextStyles.labelMedium,
                    ),
                    Text(dateStr, style: TheyDiTextStyles.caption),
                  ],
                ),
              ),
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Event name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: TheyDiColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              review.eventTitle,
              style: TheyDiTextStyles.caption.copyWith(
                color: TheyDiColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Comment
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: TheyDiTextStyles.bodySmall.copyWith(
                color: TheyDiColors.textSecondary,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
