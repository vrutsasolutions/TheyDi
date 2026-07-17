import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class FriendsService {
  FriendsService._();

  static final _db = FirebaseFirestore.instance;

  /// Send a friend request
  static Future<void> sendFriendRequest({
    required String toUid,
    required String toName,
  }) async {
    final fromUid = FirebaseAuth.instance.currentUser?.uid;
    if (fromUid == null || fromUid == toUid) return;

    final fromUser = await _db.collection('users').doc(fromUid).get();
    final fromName = fromUser.data()?['displayName'] ?? 'Someone';

    // Check if request already exists
    final existing = await _db
        .collection('users')
        .doc(toUid)
        .collection('friendRequests')
        .where('fromUid', isEqualTo: fromUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existing.docs.isNotEmpty) return;

    // Check if already friends
    final alreadyFriend = await _db
        .collection('users')
        .doc(fromUid)
        .collection('friends')
        .doc(toUid)
        .get();
    if (alreadyFriend.exists) return;

    await _db.collection('users').doc(toUid).collection('friendRequests').add({
      'fromUid': fromUid,
      'fromName': fromName,
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });

    await NotificationService.notifyFriendRequest(
      toUid: toUid,
      fromUid: fromUid,
      fromName: fromName,
    );
  }

  /// Accept a friend request
  static Future<void> acceptFriendRequest({
    required String requestId,
    required String fromUid,
    required String fromName,
  }) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final myDoc = await _db.collection('users').doc(myUid).get();
    final myName = myDoc.data()?['displayName'] ?? 'Someone';

    final batch = _db.batch();

    final requestRef = _db
        .collection('users')
        .doc(myUid)
        .collection('friendRequests')
        .doc(requestId);
    batch.update(requestRef, {'status': 'accepted'});

    batch.set(
      _db.collection('users').doc(myUid).collection('friends').doc(fromUid),
      {
        'displayName': fromName,
        'addedAt': Timestamp.now(),
        'email': '',
        'city': '',
      },
    );

    batch.set(
      _db.collection('users').doc(fromUid).collection('friends').doc(myUid),
      {
        'displayName': myName,
        'addedAt': Timestamp.now(),
        'email': '',
        'city': '',
      },
    );

    await batch.commit();

    await NotificationService.notifyFriendRequestAccepted(
      toUid: fromUid,
      accepterName: myName,
    );
  }

  /// Accept a pending request for the given user ID
  static Future<void> acceptFriendRequestByUid({
    required String otherUid,
    required String otherName,
  }) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final pendingQuery = await _db
        .collection('users')
        .doc(myUid)
        .collection('friendRequests')
        .where('fromUid', isEqualTo: otherUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (pendingQuery.docs.isEmpty) return;

    final requestId = pendingQuery.docs.first.id;
    await acceptFriendRequest(
      requestId: requestId,
      fromUid: otherUid,
      fromName: otherName,
    );
  }

  /// Decline a friend request
  static Future<void> declineFriendRequest({
    required String requestId,
    required String myUid,
  }) async {
    await _db
        .collection('users')
        .doc(myUid)
        .collection('friendRequests')
        .doc(requestId)
        .update({'status': 'declined'});
  }

  /// Remove a friend (mutual)
  static Future<void> removeFriend({required String otherUid}) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final batch = _db.batch();
    batch.delete(
        _db.collection('users').doc(myUid).collection('friends').doc(otherUid));
    batch.delete(
        _db.collection('users').doc(otherUid).collection('friends').doc(myUid));
    await batch.commit();
  }

  /// Block a user — adds to blocked list and removes friendship
  static Future<void> blockUser({required String otherUid}) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final batch = _db.batch();

    // Add to blocked list
    batch.set(
      _db.collection('users').doc(myUid).collection('blocked').doc(otherUid),
      {'blockedAt': Timestamp.now()},
    );

    // Remove friendship both ways
    batch.delete(
        _db.collection('users').doc(myUid).collection('friends').doc(otherUid));
    batch.delete(
        _db.collection('users').doc(otherUid).collection('friends').doc(myUid));

    await batch.commit();
  }

  /// Unblock a user — removes them from the blocked list
  static Future<void> unblockUser({required String otherUid}) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    await _db
        .collection('users')
        .doc(myUid)
        .collection('blocked')
        .doc(otherUid)
        .delete();
  }

  /// Check if a user is blocked by current user
  static Future<bool> isBlocked(String otherUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return false;
    final doc = await _db
        .collection('users')
        .doc(myUid)
        .collection('blocked')
        .doc(otherUid)
        .get();
    return doc.exists;
  }

  /// Get mutual circles between current user and another user
  static Future<List<Map<String, String>>> getMutualCircles(
      String otherUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return [];

    final myCircles = await FirebaseFirestore.instance
        .collection('circles')
        .where('memberUids', arrayContains: myUid)
        .get();

    final mutual = <Map<String, String>>[];
    for (final doc in myCircles.docs) {
      final members = List<String>.from(doc.data()['memberUids'] ?? []);
      if (members.contains(otherUid)) {
        mutual.add({
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Circle',
        });
      }
    }
    return mutual;
  }

  /// Get friendship status between current user and another
  static Future<FriendStatus> getFriendStatus(String otherUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || myUid == otherUid) return FriendStatus.self;

    final friendDoc = await _db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(otherUid)
        .get();
    if (friendDoc.exists) return FriendStatus.friends;

    final sentRequest = await _db
        .collection('users')
        .doc(otherUid)
        .collection('friendRequests')
        .where('fromUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (sentRequest.docs.isNotEmpty) return FriendStatus.requestSent;

    final receivedRequest = await _db
        .collection('users')
        .doc(myUid)
        .collection('friendRequests')
        .where('fromUid', isEqualTo: otherUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (receivedRequest.docs.isNotEmpty) return FriendStatus.requestReceived;

    return FriendStatus.none;
  }

  /// Stream pending friend requests
  static Stream<QuerySnapshot> streamFriendRequests(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream friends list
  static Stream<QuerySnapshot> streamFriends(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }
}

enum FriendStatus { none, requestSent, requestReceived, friends, self }
