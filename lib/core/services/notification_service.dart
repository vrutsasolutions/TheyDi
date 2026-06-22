import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'emailjs_service.dart';
 
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
      // FieldValue.serverTimestamp() is more reliable than Timestamp.now()
      // because it's set by Firestore's server clock, not the device's
      // clock — avoids skew if a user's phone time is wrong.
      'createdAt': FieldValue.serverTimestamp(),
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
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
 // ─────────────────────────────────────────────────────────
// DUAL NOTIFICATION — EMAIL + IN-APP
// ─────────────────────────────────────────────────────────

/// Friend suggestion — sends in-app + email with actual names
static Future<void> notifySuggestedFriendsDual({
  required String toUid,
  String? userEmail,
  String? userName,
  required List<String> suggestedNames,
}) async {
  // Build readable names string
  String namesText;
  if (suggestedNames.length == 1) {
    namesText = suggestedNames.first;
  } else if (suggestedNames.length == 2) {
    namesText = '${suggestedNames[0]} and ${suggestedNames[1]}';
  } else {
    final allButLast = suggestedNames.sublist(0, suggestedNames.length - 1);
    namesText = '${allButLast.join(', ')} and ${suggestedNames.last}';
  }

  // 1. In-app
  await send(
    toUid: toUid,
    title: 'People you may know 👥',
    body: 'You might know $namesText',
    type: 'suggested_friends',
  );

  // 2. Email
  final resolved = await _resolveEmailAndName(
    toUid: toUid,
    userEmail: userEmail,
    userName: userName,
  );
  if (resolved == null) return;

  await EmailJSService.sendNotificationEmail(
    toEmail: resolved.email,
    toName: resolved.name,
    title: 'People you may know 👥',
    message: 'You might know $namesText. Open the app to connect!',
  );
}

/// Event suggestion — sends in-app + email with event name and date
static Future<void> notifyEventSuggestionDual({
  required String toUid,
  String? userEmail,
  String? userName,
  required String eventTitle,
  required String eventDate,
  String? eventId,
}) async {
  // 1. In-app
  await send(
    toUid: toUid,
    title: '🎉 Event you might like',
    body: '"$eventTitle" is happening on $eventDate. Tap to view!',
    type: 'suggested_event',
    eventId: eventId,
  );

  // 2. Email
  final resolved = await _resolveEmailAndName(
    toUid: toUid,
    userEmail: userEmail,
    userName: userName,
  );
  if (resolved == null) return;

  await EmailJSService.sendNotificationEmail(
    toEmail: resolved.email,
    toName: resolved.name,
    title: '🎉 Event you might like — $eventTitle',
    message:
        '"$eventTitle" is happening on $eventDate. Open the app to view and join this event!',
  );
}

/// Notify attendee they successfully joined an event — email only
static Future<void> notifyAttendeeJoinedEmail({
  required String toUid,
  String? userEmail,
  String? userName,
  required String eventTitle,
  required String eventDate,
  required String eventVenue,
  String? eventId,
}) async {
  // 1. In-app
  await send(
    toUid: toUid,
    title: 'You\'re in! 🎉',
    body: 'You\'ve successfully joined "$eventTitle" on $eventDate',
    type: 'booking',
    eventId: eventId,
  );

  // 2. Email — confirmation to attendee
  final resolved = await _resolveEmailAndName(
    toUid: toUid,
    userEmail: userEmail,
    userName: userName,
  );
  if (resolved == null) return;

  await EmailJSService.sendNotificationEmail(
    toEmail: resolved.email,
    toName: resolved.name,
    title: 'You\'re confirmed for "$eventTitle" 🎉',
    message:
        'Hi ${resolved.name}, you have successfully joined "$eventTitle".\n\n'
        '📅 Date: $eventDate\n'
        '📍 Venue: $eventVenue\n\n'
        'We look forward to seeing you there!',
  );
}

/// Notify all attendees — event starts in 30 minutes
/// Call this from a scheduler/timer when DateTime.now() is 30 min before event
static Future<void> notifyEventStartingSoon({
  required List<String> attendeeUids,
  required String eventTitle,
  required String eventVenue,
  required String eventId,
}) async {
  for (final uid in attendeeUids) {
    // 1. In-app
    await send(
      toUid: uid,
      title: '⏰ Starting in 30 minutes!',
      body: '"$eventTitle" starts soon at $eventVenue. Get ready!',
      type: 'reminder',
      eventId: eventId,
    );

    // 2. Email
    final resolved = await _resolveEmailAndName(toUid: uid);
    if (resolved == null) continue;

    await EmailJSService.sendNotificationEmail(
      toEmail: resolved.email,
      toName: resolved.name,
      title: '⏰ "$eventTitle" starts in 30 minutes!',
      message:
          'Hi ${resolved.name}, your event "$eventTitle" is starting in 30 minutes!\n\n'
          '📍 Venue: $eventVenue\n\n'
          'Head there now so you don\'t miss anything!',
    );
  }
}

/// Notify all attendees — event has ended
/// Call this after event end time passes
static Future<void> notifyEventEnded({
  required List<String> attendeeUids,
  required String eventTitle,
  required String hostName,
  required String eventId,
}) async {
  for (final uid in attendeeUids) {
    // 1. In-app
    await send(
      toUid: uid,
      title: 'Thanks for attending! 🙌',
      body: '"$eventTitle" has ended. Hope you had a great time!',
      type: 'system',
      eventId: eventId,
    );

    // 2. Email
    final resolved = await _resolveEmailAndName(toUid: uid);
    if (resolved == null) continue;

    await EmailJSService.sendNotificationEmail(
      toEmail: resolved.email,
      toName: resolved.name,
      title: '"$eventTitle" has ended 🙌',
      message:
          'Hi ${resolved.name}, "$eventTitle" hosted by $hostName has ended.\n\n'
          'Thank you for attending! We hope you had a wonderful experience.\n\n'
          'See you at the next event!',
    );
  }
}

/// Looks up (email, name) for [toUid] from Firestore if not provided.
static Future<_EmailAndName?> _resolveEmailAndName({
  required String toUid,
  String? userEmail,
  String? userName,
}) async {
  if (userEmail != null && userEmail.isNotEmpty) {
    return _EmailAndName(userEmail, userName ?? 'there');
  }
  try {
    final userDoc = await _firestore.collection('users').doc(toUid).get();
    if (!userDoc.exists) return null;
    final data = userDoc.data()!;
    final email = data['email'] as String?;
    if (email == null || email.isEmpty) return null;
    final name = (data['fullName'] ?? data['name'] ?? 'there') as String;
    return _EmailAndName(email, name);
  } catch (e) {
    print('[NotificationService] email lookup failed: $e');
    return null;
  }
}
}

class _EmailAndName {
  final String email;
  final String name;
  _EmailAndName(this.email, this.name);
}