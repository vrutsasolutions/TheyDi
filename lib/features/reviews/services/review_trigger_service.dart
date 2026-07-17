import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:theydi/features/events/models/event_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReviewTriggerService
//
// Called once on HomeScreen init. Returns the first completed event that:
//   ✔ User attended (in attendeeUids)
//   ✔ Event is completed (endTime < now)
//   ✔ User is NOT the host
//   ✔ User has NOT already submitted a review for this event
// ─────────────────────────────────────────────────────────────────────────────
class ReviewTriggerService {
  ReviewTriggerService._();

  /// Returns the first EventModel needing a review, or null if none.
  static Future<EventModel?> getPendingReviewEvent() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      // 1. Find events this user attended
      final attendedSnap = await FirebaseFirestore.instance
          .collection('events')
          .where('attendeeUids', arrayContains: uid)
          .get();

      if (attendedSnap.docs.isEmpty) return null;

      // 2. Get all review eventIds this user has already submitted
      final givenSnap = await FirebaseFirestore.instance
          .collection('reviews')
          .where('reviewerUid', isEqualTo: uid)
          .get();
      final reviewedEventIds =
          givenSnap.docs.map((d) => d['eventId'] as String).toSet();

      // 3. Find the first completed, un-reviewed, non-hosted event
      final now = DateTime.now();
      for (final doc in attendedSnap.docs) {
        final event = EventModel.fromFirestore(doc);

        // Skip if host
        if (event.creatorUid == uid) continue;

        // Skip if not completed
        if (!event.endTime.isBefore(now)) continue;

        // Skip if already reviewed
        if (reviewedEventIds.contains(event.id)) continue;

        return event;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Quick guard used by SubmitReviewScreen — returns true if already reviewed.
  static Future<bool> hasAlreadyReviewed({
    required String eventId,
    required String reviewerUid,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('reviews')
          .where('eventId', isEqualTo: eventId)
          .where('reviewerUid', isEqualTo: reviewerUid)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
