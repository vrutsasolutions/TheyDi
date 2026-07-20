import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Result returned after a leave attempt.
class LeaveEventResult {
  final bool success;
  final String message;
  final bool refundInitiated;
  final double refundAmount;

  const LeaveEventResult({
    required this.success,
    required this.message,
    this.refundInitiated = false,
    this.refundAmount = 0.0,
  });
}

class LeaveEventService {
  LeaveEventService._();

  static const double _trustPenalty = 2.0; // points deducted per leave
  static const double _refundPercent =
      0.95; // 95% refund for paid events (5% fee deducted)

  /// Main entry point. Call this after the user confirms leaving.
  ///
  /// [eventId]   – Firestore event document ID
  /// [isFree]    – whether the event is free
  /// [price]     – ticket price (used to calculate refund)
  static Future<LeaveEventResult> leaveEvent({
    required String eventId,
    required bool isFree,
    required double price,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const LeaveEventResult(success: false, message: 'Not signed in.');
    }

    final db = FirebaseFirestore.instance;
    final eventRef = db.collection('events').doc(eventId);
    final userRef = db.collection('users').doc(uid);

    try {
      // ── Guard: duplicate leave ──────────────────────────────────────────
      final eventSnap = await eventRef.get();
      if (!eventSnap.exists) {
        return const LeaveEventResult(
            success: false, message: 'Event not found.');
      }
      final data = eventSnap.data()!;
      final attendees = List<String>.from(data['attendeeUids'] ?? []);
      if (!attendees.contains(uid)) {
        return const LeaveEventResult(
            success: false, message: 'You are not in this event.');
      }

      // ── Guard: duplicate refund ─────────────────────────────────────────
      if (!isFree) {
        final refundSnap = await db
            .collection('refunds')
            .where('userId', isEqualTo: uid)
            .where('eventId', isEqualTo: eventId)
            .limit(1)
            .get();
        if (refundSnap.docs.isNotEmpty) {
          return const LeaveEventResult(
              success: false,
              message: 'A refund for this event was already processed.');
        }
      }

      // ── Batch write ─────────────────────────────────────────────────────
      final batch = db.batch();

      // 1. Remove from attendeeUids
      batch.update(eventRef, {
        'attendeeUids': FieldValue.arrayRemove([uid]),
      });

      // 2. Decrement eventsAttended counter on user doc
      batch.update(userRef, {
        'eventsAttended': FieldValue.increment(-1),
        // Trust score: decrement (floor at 0 via max logic on read)
        'trustScore': FieldValue.increment(-_trustPenalty),
      });

      // 3. Paid event: create refund record
      double refundAmount = 0.0;
      if (!isFree && price > 0) {
        refundAmount = price * _refundPercent;
        final refundRef = db.collection('refunds').doc();
        batch.set(refundRef, {
          'userId': uid,
          'eventId': eventId,
          'originalAmount': price,
          'refundAmount': refundAmount,
          'refundPercent': (_refundPercent * 100).toInt(),
          'status': 'pending', // pending → processed by backend
          'reason': 'user_left_event',
          'createdAt': Timestamp.now(),
          'estimatedDays': 7,
        });
      }

      // Find and update the booking to 'cancelled' (for both free and paid)
      final bookingQuery = await db
          .collection('bookings')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'confirmed')
          .get();

      for (var doc in bookingQuery.docs) {
        batch.update(doc.reference, {'status': 'cancelled'});
      }

      if (!isFree) {
        final paymentRef = eventRef.collection('attendeePayments').doc(uid);
        batch.set(paymentRef, {'status': 'refunded'}, SetOptions(merge: true));
      }

      // 4. Leave activity log (for trust audit trail)
      final logRef =
          db.collection('users').doc(uid).collection('activityLog').doc();
      batch.set(logRef, {
        'type': 'left_event',
        'eventId': eventId,
        'isFree': isFree,
        'trustPenalty': _trustPenalty,
        'refundAmount': refundAmount,
        'timestamp': Timestamp.now(),
      });

      await batch.commit();

      if (!isFree && refundAmount > 0) {
        return LeaveEventResult(
          success: true,
          message: 'You have left the event.',
          refundInitiated: true,
          refundAmount: refundAmount,
        );
      }

      return const LeaveEventResult(
        success: true,
        message: 'You have successfully left the event.',
      );
    } catch (e) {
      return LeaveEventResult(success: false, message: 'Failed to leave: $e');
    }
  }
}
