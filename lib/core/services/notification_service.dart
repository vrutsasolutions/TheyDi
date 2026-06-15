import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  NotificationService._();

  static final _firestore = FirebaseFirestore.instance;

  /// Send a notification to a specific user
  static Future<void> send({
    required String toUid,
    required String title,
    required String body,
    required String type,
    String? eventId,
    String? fromUid,
    String? circleId,
    String? chatId,
  }) async {
    if (chatId != null) {
      final muteDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('mutedBy')
          .doc(toUid)
          .get();
      if (muteDoc.exists) return;
    }

    await _firestore
        .collection('users')
        .doc(toUid)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'eventId': eventId,
      'fromUid': fromUid,
      'circleId': circleId,
      'chatId': chatId,
      'createdAt': Timestamp.now(),
    });
  }

  // ─────────────────────────────────────────────────────────
  // EVENT NOTIFICATIONS
  // ─────────────────────────────────────────────────────────

  static Future<void> notifyJoinRequest({
    required String hostUid,
    required String requesterName,
    required String eventTitle,
    required String eventId,
  }) async {
    await send(
      toUid: hostUid,
      title: 'New join request',
      body: '$requesterName wants to join "$eventTitle"',
      type: 'booking',
      eventId: eventId,
    );
  }

  static Future<void> notifyRequestApproved({
    required String userUid,
    required String eventTitle,
    required String hostName,
    required String eventId,
  }) async {
    await send(
      toUid: userUid,
      title: 'Request approved! 🎉',
      body: '$hostName approved your request to join "$eventTitle"',
      type: 'booking',
      eventId: eventId,
    );
  }

  static Future<void> notifyRequestRejected({
    required String userUid,
    required String eventTitle,
    required String hostName,
    required String eventId,
  }) async {
    await send(
      toUid: userUid,
      title: 'Request declined',
      body: '$hostName declined your request to join "$eventTitle"',
      type: 'booking',
      eventId: eventId,
    );
  }

  static Future<void> notifyUserCancelledSpot({
    required String hostUid,
    required String userName,
    required String eventTitle,
    required String eventId,
  }) async {
    await send(
      toUid: hostUid,
      title: 'Spot cancelled',
      body: '$userName cancelled their spot in "$eventTitle"',
      type: 'booking',
      eventId: eventId,
    );
  }

  static Future<void> notifyEventCancelledToAttendees({
    required List<String> attendeeUids,
    required String eventTitle,
    required String hostName,
    required String eventId,
  }) async {
    await Future.wait(
      attendeeUids.map((uid) => send(
            toUid: uid,
            title: 'Event cancelled 😔',
            body:
                '$hostName cancelled "$eventTitle". We\'re sorry for the inconvenience.',
            type: 'system',
            eventId: eventId,
          )),
    );
  }

  static Future<void> notifyFreeEventJoined({
    required String userUid,
    required String eventTitle,
    required String eventId,
  }) async {
    await send(
      toUid: userUid,
      title: 'You\'re in! 🎉',
      body: 'You\'ve successfully joined "$eventTitle"',
      type: 'booking',
      eventId: eventId,
    );
  }

  static Future<void> notifyPaymentConfirmed({
    required String userUid,
    required String eventTitle,
    required String amount,
    required String eventId,
  }) async {
    await send(
      toUid: userUid,
      title: 'Payment confirmed',
      body: '₹$amount paid for "$eventTitle". You\'re all set!',
      type: 'payment',
      eventId: eventId,
    );
  }

  static Future<void> notifyHostNewBooking({
    required String hostUid,
    required String attendeeName,
    required String eventTitle,
    required String amount,
    required String eventId,
  }) async {
    await send(
      toUid: hostUid,
      title: 'New booking! 💰',
      body: '$attendeeName booked "$eventTitle" for ₹$amount',
      type: 'payment',
      eventId: eventId,
    );
  }

  static Future<void> notifyEventReminder({
    required String userUid,
    required String eventTitle,
    required String venue,
    required String eventId,
  }) async {
    await send(
      toUid: userUid,
      title: 'Event tomorrow! 📅',
      body: '"$eventTitle" is happening tomorrow at $venue. Don\'t forget!',
      type: 'reminder',
      eventId: eventId,
    );
  }

  // ─────────────────────────────────────────────────────────
  // FRIEND NOTIFICATIONS
  // ─────────────────────────────────────────────────────────

  static Future<void> notifyFriendRequest({
    required String toUid,
    required String fromUid,
    required String fromName,
  }) async {
    await send(
      toUid: toUid,
      title: 'Friend request 👋',
      body: '$fromName wants to connect with you',
      type: 'social',
      fromUid: fromUid,
    );
  }

  static Future<void> notifyFriendRequestAccepted({
    required String toUid,
    required String accepterName,
  }) async {
    await send(
      toUid: toUid,
      title: 'Friend request accepted! 🎉',
      body: '$accepterName accepted your friend request',
      type: 'social',
    );
  }

  /// Notify user about new suggested friends (batch — sent at most once per day)
  static Future<void> notifySuggestedFriends({
    required String toUid,
    required int count,
  }) async {
    // Avoid spam: check if already sent today
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final existing = await _firestore
        .collection('users')
        .doc(toUid)
        .collection('notifications')
        .where('type', isEqualTo: 'suggested_friends')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(startOfDay))
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return; // already sent today

    await send(
      toUid: toUid,
      title: 'People you may know 👥',
      body: 'We found $count people you might want to connect with',
      type: 'suggested_friends',
    );
  }

  // ─────────────────────────────────────────────────────────
  // CIRCLE NOTIFICATIONS
  // ─────────────────────────────────────────────────────────

  /// Notify circle admin when someone requests to join
  static Future<void> notifyCircleJoinRequest({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String circleName,
    required String circleId,
  }) async {
    await send(
      toUid: toUid,
      title: 'Circle join request 🔵',
      body: '$fromName wants to join "$circleName"',
      type: 'circle_join_request',
      fromUid: fromUid,
      circleId: circleId,
    );
  }

  /// Notify user when their circle join request is approved
  static Future<void> notifyCircleJoinApproved({
    required String toUid,
    required String circleName,
    required String circleId,
  }) async {
    await send(
      toUid: toUid,
      title: 'Welcome to the circle! 🎉',
      body: 'Your request to join "$circleName" was approved',
      type: 'circle_approved',
      circleId: circleId,
    );
  }

  /// Notify user when their circle join request is rejected
  static Future<void> notifyCircleJoinRejected({
    required String toUid,
    required String circleName,
  }) async {
    await send(
      toUid: toUid,
      title: 'Circle request declined',
      body: 'Your request to join "$circleName" was not approved',
      type: 'circle_rejected',
    );
  }

  /// Notify user when removed from a circle
  static Future<void> notifyRemovedFromCircle({
    required String userUid,
    required String circleName,
    required String removedByName,
    String? circleId,
  }) async {
    await send(
      toUid: userUid,
      title: 'Removed from circle',
      body: 'You were removed from "$circleName" by $removedByName',
      type: 'circle_removed',
      circleId: circleId,
    );
  }

  /// Notify user about suggested circles (at most once per day)
  static Future<void> notifySuggestedCircles({
    required String toUid,
    required int count,
  }) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final existing = await _firestore
        .collection('users')
        .doc(toUid)
        .collection('notifications')
        .where('type', isEqualTo: 'suggested_circles')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(startOfDay))
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    await send(
      toUid: toUid,
      title: 'Circles you might like 🔵',
      body: 'We found $count circles based on your interests and city',
      type: 'suggested_circles',
    );
  }

  // ─────────────────────────────────────────────────────────
  // ONLINE STATUS
  // ─────────────────────────────────────────────────────────

  static Future<void> setOnlineStatus(bool isOnline) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': Timestamp.now(),
      });
    } catch (_) {}
  }
}
