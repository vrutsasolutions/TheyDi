// ─────────────────────────────────────────────────────────────────────────────
// CHANGES vs original submit_review_screen.dart
//
//  1. Added optional `initialRating` constructor param — so the popup's
//     star tap pre-fills the rating when navigating here.
//  2. initState: calls ReviewTriggerService.hasAlreadyReviewed() — if already
//     reviewed, shows a snackbar and pops immediately. Prevents duplicates.
//  3. All submission logic, UI, and _updateHostRating unchanged.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../events/models/event_model.dart';
import '../models/review_model.dart';
import '../services/review_trigger_service.dart'; // ← NEW

class SubmitReviewScreen extends StatefulWidget {
  final EventModel event;
  final double initialRating; // ← NEW: pre-fill from popup star tap

  const SubmitReviewScreen({
    super.key,
    required this.event,
    this.initialRating = 0, // ← NEW
  });

  @override
  State<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  late double _rating;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _checkingDuplicate = true; // ← NEW

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating; // ← NEW
    _guardDuplicate(); // ← NEW
  }

  // ── NEW: guard against duplicate submission ──
  Future<void> _guardDuplicate() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final alreadyReviewed = await ReviewTriggerService.hasAlreadyReviewed(
      eventId: widget.event.id,
      reviewerUid: uid,
    );
    if (!mounted) return;
    if (alreadyReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already reviewed this event.'),
          backgroundColor: Colors.amber,
        ),
      );
      context.pop();
      return;
    }
    setState(() => _checkingDuplicate = false);
  }

  String get _ratingLabel {
    if (_rating >= 5) return 'Amazing! 🤩';
    if (_rating >= 4) return 'Great! 😄';
    if (_rating >= 3) return 'Good 🙂';
    if (_rating >= 2) return 'Okay 😐';
    if (_rating >= 1) return 'Poor 😕';
    return 'Tap a star to rate';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    // Final duplicate guard before write
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final alreadyReviewed = await ReviewTriggerService.hasAlreadyReviewed(
      eventId: widget.event.id,
      reviewerUid: uid,
    );
    if (alreadyReviewed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already reviewed this event.'),
            backgroundColor: Colors.amber,
          ),
        );
        context.pop();
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      String reviewerName = user.displayName ?? user.email!.split('@').first;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          reviewerName = userDoc.data()?['displayName'] ?? reviewerName;
        }
      } catch (_) {}

      String hostName = widget.event.creatorName;
      try {
        final hostDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.event.creatorUid)
            .get();
        if (hostDoc.exists) {
          hostName = hostDoc.data()?['displayName'] ?? hostName;
        }
      } catch (_) {}

      final review = ReviewModel(
        id: '',
        eventId: widget.event.id,
        eventTitle: widget.event.title,
        reviewerUid: user.uid,
        reviewerName: reviewerName,
        hostUid: widget.event.creatorUid,
        hostName: hostName,
        rating: _rating,
        comment: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('reviews')
          .add(review.toFirestoreMap());

      await _updateHostRating(widget.event.creatorUid);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.event.creatorUid)
          .collection('notifications')
          .add({
        'title': 'New review received ⭐',
        'body':
            '$reviewerName rated "${widget.event.title}" ${_rating.toStringAsFixed(0)} stars',
        'type': 'social',
        'isRead': false,
        'eventId': widget.event.id,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted! Thanks for your feedback 🎉'),
          backgroundColor: Colors.green,
        ),
      );

      context.pop();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateHostRating(String hostUid) async {
    final reviews = await FirebaseFirestore.instance
        .collection('reviews')
        .where('hostUid', isEqualTo: hostUid)
        .get();

    if (reviews.docs.isEmpty) return;

    double totalRating = 0;
    for (final doc in reviews.docs) {
      totalRating += (doc.data()['rating'] ?? 0).toDouble();
    }
    final avgRating = totalRating / reviews.docs.length;

    await FirebaseFirestore.instance.collection('users').doc(hostUid).update({
      'avgRating': double.parse(avgRating.toStringAsFixed(1)),
      'totalReviews': reviews.docs.length,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show spinner while duplicate check runs
    if (_checkingDuplicate) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [TheyDiColors.cardLight, TheyDiColors.surface],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(
              child: CircularProgressIndicator(color: TheyDiColors.primary)),
        ),
      );
    }

    return Scaffold(
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
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: TheyDiColors.textPrimary),
                      onPressed: _isSubmitting ? null : () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text('Leave a Review',
                        style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // Event info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TheyDiColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TheyDiColors.divider),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: TheyDiColors.gradientPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                widget.event.category.isNotEmpty
                                    ? widget.event.category[0]
                                    : 'E',
                                style: TheyDiTextStyles.displayMedium.copyWith(
                                    color: Colors.white, fontSize: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.event.title,
                                    style: TheyDiTextStyles.labelLarge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text('Hosted by ${widget.event.creatorName}',
                                    style: TheyDiTextStyles.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 100.ms).fade(duration: 400.ms),

                    const SizedBox(height: 32),

                    // Rating label
                    Center(
                      child: Text(
                        _ratingLabel,
                        style: TheyDiTextStyles.headlineMedium.copyWith(
                          color: _rating > 0
                              ? Colors.amber
                              : TheyDiColors.textSecondary,
                        ),
                      ),
                    ).animate(delay: 150.ms).fade(duration: 300.ms),

                    const SizedBox(height: 16),

                    // Stars
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          final starValue = index + 1.0;
                          return GestureDetector(
                            onTap: () => setState(() => _rating = starValue),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                starValue <= _rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: starValue <= _rating
                                    ? Colors.amber
                                    : TheyDiColors.textMuted,
                                size: 48,
                              ),
                            ),
                          );
                        }),
                      ),
                    ).animate(delay: 200.ms).fade(duration: 400.ms).scale(
                        begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),

                    const SizedBox(height: 32),

                    // Comment
                    Text('Your feedback (optional)',
                            style: TheyDiTextStyles.labelMedium)
                        .animate(delay: 300.ms)
                        .fade(duration: 300.ms),
                    const SizedBox(height: 8),

                    TextField(
                      controller: _commentController,
                      style: TheyDiTextStyles.bodyMedium,
                      maxLines: 5,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'What did you enjoy? Any suggestions?',
                        hintStyle: TheyDiTextStyles.bodySmall.copyWith(
                          color: TheyDiColors.textMuted,
                        ),
                        filled: true,
                        fillColor: TheyDiColors.card,
                        counterStyle: TextStyle(color: TheyDiColors.textMuted),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: TheyDiColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: TheyDiColors.primary),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ).animate(delay: 350.ms).fade(duration: 300.ms),

                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: _isSubmitting
                              ? null
                              : TheyDiColors.gradientPrimary,
                          color: _isSubmitting ? Colors.grey[800] : null,
                        ),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  'Submit Review',
                                  style: TheyDiTextStyles.labelLarge.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ).animate(delay: 400.ms).fade(duration: 300.ms),

                    const SizedBox(height: 40),
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
