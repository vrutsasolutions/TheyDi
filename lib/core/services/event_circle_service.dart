import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/circles/models/circle_model.dart';
import '../../features/events/models/event_model.dart';

class EventCircleService {
  EventCircleService._();

  /// Check if an event circle already exists for this event
  static Future<CircleModel?> getExistingEventCircle(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snap = await FirebaseFirestore.instance
        .collection('circles')
        .where('type', isEqualTo: 'event')
        .where('eventId', isEqualTo: eventId)
        .where('memberUids', arrayContains: user.uid)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      return CircleModel.fromFirestore(snap.docs.first);
    }
    return null;
  }

  /// Create an event circle with all approved attendees — no duplicates
  static Future<CircleModel> createEventCircle({
    required EventModel event,
    required List<String> attendeeUids,
    required List<String> attendeeNames,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;

    String creatorName = user.displayName ?? 'Host';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        creatorName = userDoc.data()?['displayName'] ?? creatorName;
      }
    } catch (_) {}

    // Build deduplicated member list — creator always first
    final Map<String, String> memberMap = {user.uid: creatorName};
    for (int i = 0; i < attendeeUids.length; i++) {
      final uid = attendeeUids[i];
      if (!memberMap.containsKey(uid)) {
        memberMap[uid] =
            i < attendeeNames.length ? attendeeNames[i] : 'Member';
      }
    }

    final memberUids = memberMap.keys.toList();
    final memberNames = memberMap.values.toList();
    final circleName = '${event.title} Circle';

    final circleRef =
        await FirebaseFirestore.instance.collection('circles').add({
      'name': circleName,
      'description': 'Group for ${event.title} attendees',
      'creatorUid': user.uid,
      'creatorName': creatorName,
      'memberUids': memberUids,
      'memberNames': memberNames,
      'lastMessage': null,
      'lastMessageSender': null,
      'lastMessageAt': null,
      'createdAt': Timestamp.now(),
      'type': 'event',
      'eventId': event.id,
    });

    // Notify all members except creator
    for (final uid in memberUids) {
      if (uid == user.uid) continue;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': 'Added to event circle 🎉',
        'body': '$creatorName added you to "$circleName"',
        'type': 'social',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    }

    final circleDoc = await circleRef.get();
    return CircleModel.fromFirestore(circleDoc);
  }

  /// Add a member to an existing circle
  static Future<void> addMemberToCircle({
    required String circleId,
    required String userUid,
    required String userName,
  }) async {
    await FirebaseFirestore.instance
        .collection('circles')
        .doc(circleId)
        .update({
      'memberUids': FieldValue.arrayUnion([userUid]),
      'memberNames': FieldValue.arrayUnion([userName]),
    });
  }

  /// Remove a member from a circle (host only)
  /// Also sends a notification to the removed user
  static Future<void> removeMemberFromCircle({
    required String circleId,
    required String userUid,
    required String userName,
  }) async {
    // Get circle name + admin name for notification
    String circleName = 'the circle';
    String adminName = 'Admin';
    try {
      final circleDoc = await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .get();
      if (circleDoc.exists) {
        circleName = circleDoc.data()?['name'] ?? circleName;
        final adminUid = circleDoc.data()?['creatorUid'] ?? '';
        if (adminUid.isNotEmpty) {
          final adminDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(adminUid)
              .get();
          adminName = adminDoc.data()?['displayName'] ?? adminName;
        }
      }
    } catch (_) {}

    // Remove from memberUids and memberNames atomically
    await FirebaseFirestore.instance
        .collection('circles')
        .doc(circleId)
        .update({
      'memberUids': FieldValue.arrayRemove([userUid]),
      'memberNames': FieldValue.arrayRemove([userName]),
    });

    // Notify removed user
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userUid)
        .collection('notifications')
        .add({
      'title': 'Removed from circle',
      'body': '$adminName removed you from "$circleName"',
      'type': 'social',
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }
}