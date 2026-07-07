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
 
  static Future<void> notifyHostNewAttendeeEmail({
    required String hostUid,
    required String attendeeName,
    required String eventTitle,
    required String amount,
    required String eventId,
    String? hostEmail,
    String? hostName,
  }) async {
    final isFree = amount == '0' || amount == '0.0';
    
    // 1. In-app
    await send(
      toUid: hostUid,
      title: isFree ? 'New attendee! 🎉' : 'New booking! 💰',
      body: isFree
          ? '$attendeeName joined "$eventTitle"'
          : '$attendeeName booked "$eventTitle" for ₹$amount',
      type: 'payment',
      eventId: eventId,
    );

    // 2. Email
    final resolved = await _resolveEmailAndName(
      toUid: hostUid, userEmail: hostEmail, userName: hostName,
    );
    if (resolved == null) return;

    await EmailJSService.sendNotificationEmail(
      toEmail: resolved.email,
      toName: resolved.name,
      title: isFree ? '🎉 New attendee joined — $eventTitle' : '💰 New booking received — $eventTitle',
      message:
          'Hi ${resolved.name},\n\n'
          'Great news! $attendeeName has just ${isFree ? 'joined' : 'booked a spot for'} your event "$eventTitle"${isFree ? '.' : ' for ₹$amount.'}\n\n'
          'You can view their details in your Host Dashboard.',
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
    // 1. In-app notification
    await send(
      toUid: toUid,
      title: 'Friend request 👋',
      body: '$fromName wants to connect with you',
      type: 'social',
      fromUid: fromUid,
    );

    // 2. Email notification
    final resolved = await _resolveEmailAndName(toUid: toUid);
    if (resolved == null) return;

    await EmailJSService.sendNotificationEmail(
      toEmail: resolved.email,
      toName: resolved.name,
      title: '👋 New Friend Request from $fromName',
      message: 'Hi ${resolved.name},\n\n'
          '$fromName has sent you a friend request on TheyDi.\n\n'
          'Open the app to review and accept the request to start connecting!',
    );
  }
 
  static Future<void> notifyFriendRequestAccepted({
    required String toUid,
    required String accepterName,
  }) async {
    // 1. In-app notification
    await send(
      toUid: toUid,
      title: 'Friend request accepted! 🎉',
      body: '$accepterName accepted your friend request',
      type: 'social',
    );

    // 2. Email notification
    final resolved = await _resolveEmailAndName(toUid: toUid);
    if (resolved == null) return;

    await EmailJSService.sendNotificationEmail(
      toEmail: resolved.email,
      toName: resolved.name,
      title: '🎉 $accepterName accepted your friend request!',
      message: 'Hi ${resolved.name},\n\n'
          'Great news! $accepterName has accepted your friend request on TheyDi.\n\n'
          'Open the app to say hi and start a conversation!',
    );
  }
 
  /// Notify user about new suggested friends (batch — sent at most once per day)
  static Future<void> notifySuggestedFriends({
    required String toUid,
    required int count,
  }) async {
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
 
    if (existing.docs.isNotEmpty) return;
 
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
    String namesText;
    if (suggestedNames.length == 1) {
      namesText = suggestedNames.first;
    } else if (suggestedNames.length == 2) {
      namesText = '${suggestedNames[0]} and ${suggestedNames[1]}';
    } else {
      final allButLast = suggestedNames.sublist(0, suggestedNames.length - 1);
      namesText = '${allButLast.join(', ')} and ${suggestedNames.last}';
    }

    await send(
      toUid: toUid,
      title: 'People you may know 👥',
      body: 'You might know $namesText',
      type: 'suggested_friends',
    );

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
    await send(
      toUid: toUid,
      title: '🎉 Event you might like',
      body: '"$eventTitle" is happening on $eventDate. Tap to view!',
      type: 'suggested_event',
      eventId: eventId,
    );

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
    await send(
      toUid: toUid,
      title: 'You\'re in! 🎉',
      body: 'You\'ve successfully joined "$eventTitle" on $eventDate',
      type: 'booking',
      eventId: eventId,
    );

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
  static Future<void> notifyEventStartingSoon({
    required List<String> attendeeUids,
    required String eventTitle,
    required String eventVenue,
    required String eventId,
  }) async {
    for (final uid in attendeeUids) {
      await send(
        toUid: uid,
        title: '⏰ Starting in 30 minutes!',
        body: '"$eventTitle" starts soon at $eventVenue. Get ready!',
        type: 'reminder',
        eventId: eventId,
      );

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
  static Future<void> notifyEventEnded({
    required List<String> attendeeUids,
    required String eventTitle,
    required String hostName,
    required String eventId,
  }) async {
    for (final uid in attendeeUids) {
      await send(
        toUid: uid,
        title: 'Thanks for attending! 🙌',
        body: '"$eventTitle" has ended. Hope you had a great time!',
        type: 'system',
        eventId: eventId,
      );

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

  // ─────────────────────────────────────────────────────────
  // NEW: PAYMENT RECEIVED — attendee in-app + email receipt
  // ─────────────────────────────────────────────────────────

  /// Sends in-app + email receipt to the attendee after a successful payment.
  static Future<void> notifyPaymentReceivedEmail({
    required String userUid,
    required String eventTitle,
    required String eventDate,
    required String eventVenue,
    required String amount,
    required String transactionId,
    required String eventId,
    String? userEmail,
    String? userName,
  }) async {
    // 1. In-app
    await send(
      toUid: userUid,
      title: '✅ Payment confirmed',
      body: '₹$amount paid for "$eventTitle". You\'re all set!',
      type: 'payment',
      eventId: eventId,
    );
    // 2. Email
    final resolved = await _resolveEmailAndName(
      toUid: userUid, userEmail: userEmail, userName: userName,
    );
    if (resolved == null) return;
    await EmailJSService.sendNotificationEmail(
      toEmail: resolved.email,
      toName: resolved.name,
      title: '✅ Payment Confirmed — $eventTitle',
      message:
          'Hi ${resolved.name}, your payment of ₹$amount has been received!\n\n'
          '🎟️ Event: $eventTitle\n'
          '📅 Date: $eventDate\n'
          '📍 Venue: $eventVenue\n'
          '🔖 Transaction ID: $transactionId\n\n'
          'See you there!',
    );
  }

  // ─────────────────────────────────────────────────────────
  // NEW: HOST PAYOUT RECEIVED
  // ─────────────────────────────────────────────────────────

  /// Sends in-app + email to the host when a payout is processed.
  static Future<void> notifyHostPayoutEmail({
    required String hostUid,
    required String eventTitle,
    required int bookingsProcessed,
    required String totalAmount,
    String? hostEmail,
    String? hostName,
  }) async {
    // 1. In-app
    await send(
      toUid: hostUid,
      title: '💰 Payout processed!',
      body: 'Your payout for "$eventTitle" ($bookingsProcessed bookings) is on its way.',
      type: 'payment',
    );
    // 2. Email
    final resolved = await _resolveEmailAndName(
      toUid: hostUid, userEmail: hostEmail, userName: hostName,
    );
    if (resolved == null) return;
    await EmailJSService.sendNotificationEmail(
      toEmail: resolved.email,
      toName: resolved.name,
      title: '💰 Payout Processed — $eventTitle',
      message:
          'Hi ${resolved.name}, your payout for "$eventTitle" has been processed!\n\n'
          '📦 Bookings processed: $bookingsProcessed\n'
          '💵 Total transferred: ₹$totalAmount\n\n'
          'Funds will reflect in your bank account within 2–3 business days.',
    );
  }

  // ─────────────────────────────────────────────────────────
  // NEW: EVENT CREATED — host confirmation
  // ─────────────────────────────────────────────────────────

  /// Sends in-app + email to the host confirming their event was created.
  static Future<void> notifyEventCreatedEmail({
    required String hostUid,
    required String eventTitle,
    required String eventDate,
    required String eventVenue,
    required String eventId,
    String? hostEmail,
    String? hostName,
  }) async {
    // 1. In-app
    await send(
      toUid: hostUid,
      title: '🎉 Event created!',
      body: '"$eventTitle" is now live. Share it and start inviting people!',
      type: 'system',
      eventId: eventId,
    );
    // 2. Email
    final resolved = await _resolveEmailAndName(
      toUid: hostUid, userEmail: hostEmail, userName: hostName,
    );
    if (resolved == null) return;
    await EmailJSService.sendNotificationEmail(
      toEmail: resolved.email,
      toName: resolved.name,
      title: '🎉 Your Event is Live — $eventTitle',
      message:
          'Hi ${resolved.name}, your event has been successfully created!\n\n'
          '📌 Event: $eventTitle\n'
          '📅 Date: $eventDate\n'
          '📍 Venue: $eventVenue\n\n'
          'Share the event with your network to get attendees. '
          'You can manage everything from the Host Dashboard.',
    );
  }

  // ─────────────────────────────────────────────────────────
  // NEW: EVENT COMPLETED — all attendees + host
  // ─────────────────────────────────────────────────────────

  /// Sends in-app + email to every attendee and the host when event completes.
  static Future<void> notifyEventCompletedToAll({
    required List<String> attendeeUids,
    required String hostUid,
    required String eventTitle,
    required String hostName,
    required String eventId,
  }) async {
    // Notify each attendee
    for (final uid in attendeeUids) {
      await send(
        toUid: uid,
        title: '🙌 Thanks for attending!',
        body: '"$eventTitle" has wrapped up. Hope you had a great time!',
        type: 'system',
        eventId: eventId,
      );
      final resolved = await _resolveEmailAndName(toUid: uid);
      if (resolved == null) continue;
      await EmailJSService.sendNotificationEmail(
        toEmail: resolved.email,
        toName: resolved.name,
        title: '🙌 "$eventTitle" has ended',
        message:
            'Hi ${resolved.name}, "$eventTitle" hosted by $hostName has ended.\n\n'
            'Thank you for being there! We hope you had a wonderful experience.\n\n'
            'If you enjoyed the event, consider leaving a review for the host on TheyDi.',
      );
    }
    // Notify host
    await send(
      toUid: hostUid,
      title: '✅ Event completed',
      body: '"$eventTitle" is now marked as completed.',
      type: 'system',
      eventId: eventId,
    );
    final hostResolved = await _resolveEmailAndName(toUid: hostUid);
    if (hostResolved != null) {
      await EmailJSService.sendNotificationEmail(
        toEmail: hostResolved.email,
        toName: hostResolved.name,
        title: '✅ Event Completed — $eventTitle',
        message:
            'Hi ${hostResolved.name}, your event "$eventTitle" has been marked as completed '
            'and payouts are being processed.\n\n'
            'Thank you for hosting on TheyDi!',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // NEW: EVENT DELETED BY HOST — attendees in-app + email
  // ─────────────────────────────────────────────────────────

  /// Sends in-app + email to all attendees when host cancels/deletes an event.
  static Future<void> notifyEventDeletedToAttendees({
    required List<String> attendeeUids,
    required String eventTitle,
    required String hostName,
    required String eventId,
  }) async {
    for (final uid in attendeeUids) {
      // 1. In-app
      await send(
        toUid: uid,
        title: 'Event cancelled 😔',
        body: '$hostName cancelled "$eventTitle". Sorry for the inconvenience.',
        type: 'system',
        eventId: eventId,
      );
      // 2. Email
      final resolved = await _resolveEmailAndName(toUid: uid);
      if (resolved == null) continue;
      await EmailJSService.sendNotificationEmail(
        toEmail: resolved.email,
        toName: resolved.name,
        title: '😔 "$eventTitle" has been cancelled',
        message:
            'Hi ${resolved.name}, we\'re sorry to inform you that '
            '"$eventTitle" hosted by $hostName has been cancelled.\n\n'
            'If you paid for this event, a refund will be initiated. '
            'Please contact support if you have any questions.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────

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
      final name = (data['displayName'] ?? data['fullName'] ?? data['name'] ?? 'there') as String;
      return _EmailAndName(email, name);
    } catch (e) {
      // ignore: avoid_print
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