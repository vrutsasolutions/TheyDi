import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

/// Manages circle join requests (request → admin approves/rejects → member added)
class CircleJoinService {
  CircleJoinService._();

  static final _db = FirebaseFirestore.instance;

  // ── Send a join request ──────────────────────────────────────────────────
  static Future<void> sendJoinRequest({
    required String circleId,
    required String circleName,
    required String adminUid,
    String? circleDescription,
    int? circleMemberCount,
    String? creatorName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await _db.collection('users').doc(uid).get();
    final userName = (userDoc.data()?['displayName'] as String?) ?? 'Someone';

    // Avoid duplicate requests
    final existing = await _db
        .collection('circles')
        .doc(circleId)
        .collection('joinRequests')
        .doc(uid)
        .get();
    if (existing.exists) return;

    // Write request
    await _db
        .collection('circles')
        .doc(circleId)
        .collection('joinRequests')
        .doc(uid)
        .set({
      'fromUid': uid,
      'fromName': userName,
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });

// Mirror under the user for fast "my pending requests" lookups
    await _db
        .collection('users')
        .doc(uid)
        .collection('pendingCircleRequests')
        .doc(circleId)
        .set({
      'circleId': circleId,
      'circleName': circleName,
      'description': circleDescription ?? '',
      'memberCount': circleMemberCount ?? 0,
      'creatorName': creatorName ?? '',
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });

    // Notify admin
    await NotificationService.notifyCircleJoinRequest(
      toUid: adminUid,
      fromUid: uid,
      fromName: userName,
      circleName: circleName,
      circleId: circleId,
    );  }

// ── Approve a join request ───────────────────────────────────────────────
  static Future<void> approveJoinRequest({
    required String circleId,
    required String circleName,
    required String requesterUid,
    required String requesterName,
  }) async {
    final batch = _db.batch();

    final circleRef = _db.collection('circles').doc(circleId);
    final requestRef = circleRef.collection('joinRequests').doc(requesterUid);
    final mirrorRef = _db
        .collection('users')
        .doc(requesterUid)
        .collection('pendingCircleRequests')
        .doc(circleId);

    // Add user to circle members
    batch.update(circleRef, {
      'memberUids': FieldValue.arrayUnion([requesterUid]),
      'memberNames': FieldValue.arrayUnion([requesterName]),
    });

    // Mark request as approved
    batch.update(requestRef, {'status': 'approved'});

    // Remove from user's pending mirror (now a member)
    batch.delete(mirrorRef);

    await batch.commit();

    // Notify requester
    await NotificationService.notifyCircleJoinApproved(
      toUid: requesterUid,
      circleName: circleName,
      circleId: circleId,
    );
  }
// ── Reject a join request ────────────────────────────────────────────────
  static Future<void> rejectJoinRequest({
    required String circleId,
    required String circleName,
    required String requesterUid,
  }) async {
    final batch = _db.batch();

    final requestRef = _db
        .collection('circles')
        .doc(circleId)
        .collection('joinRequests')
        .doc(requesterUid);
    final mirrorRef = _db
        .collection('users')
        .doc(requesterUid)
        .collection('pendingCircleRequests')
        .doc(circleId);

    batch.update(requestRef, {'status': 'rejected'});
    batch.delete(mirrorRef);

    await batch.commit();

    await NotificationService.notifyCircleJoinRejected(
      toUid: requesterUid,
      circleName: circleName,
    );
  }

  // ── Get join request status for current user ─────────────────────────────
  static Future<String?> getJoinRequestStatus(String circleId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _db
        .collection('circles')
        .doc(circleId)
        .collection('joinRequests')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return doc.data()?['status'] as String?;
  }

  // ── Stream pending join requests for a circle (admin view) ───────────────
  static Stream<List<Map<String, dynamic>>> streamPendingRequests(
      String circleId) {
    return _db
        .collection('circles')
        .doc(circleId)
        .collection('joinRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              return {'id': d.id, ...data};
            }).toList());
  }

  // ── Suggested circles (city + interests match, not already member) ────────
  static Future<List<Map<String, dynamic>>> getSuggestedCircles() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final city = (userData['city'] as String?) ?? '';
    final interests = List<String>.from(userData['interests'] ?? []);

    // Fetch all custom circles where user is NOT a member
    final allCirclesSnap = await _db
        .collection('circles')
        .where('type', isEqualTo: 'custom')
        .limit(60)
        .get();

    final suggestions = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final doc in allCirclesSnap.docs) {
      final data = doc.data();
      final memberUids = List<String>.from(data['memberUids'] ?? []);
      if (memberUids.contains(uid)) continue; // already a member
      if (seen.contains(doc.id)) continue;

      // Score by city + interests overlap
      int score = 0;
      final circleCity = (data['city'] as String?) ?? '';
      if (city.isNotEmpty && circleCity == city) score += 2;

      // Check member interests overlap
      final memberUidsForScore = memberUids.take(5).toList();
      if (interests.isNotEmpty && memberUidsForScore.isNotEmpty) {
        score += 1; // basic relevance
      }

      if (score > 0) {
        seen.add(doc.id);
        suggestions.add({
          'id': doc.id,
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
          'memberCount': memberUids.length,
          'creatorUid': data['creatorUid'] ?? '',
          'creatorName': data['creatorName'] ?? '',
          'score': score,
        });
      }
    }

    suggestions.sort((a, b) => (b['score'] as int) - (a['score'] as int));
    return suggestions.take(10).toList();
  }

  // ── Suggested friends (shared interests + event co-attendance) ────────────
  static Future<List<Map<String, dynamic>>> getSuggestedFriends() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    // Get current friends & sent requests to exclude
    final friendsSnap =
        await _db.collection('users').doc(uid).collection('friends').get();
    final friendUids = friendsSnap.docs.map((d) => d.id).toSet();

    final pendingSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .get();
    final pendingUids = pendingSnap.docs
        .map((d) => (d.data()['fromUid'] ?? '') as String)
        .toSet();

    final excluded = {uid, ...friendUids, ...pendingUids};

    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final myInterests = List<String>.from(userData['interests'] ?? []);
    final myCity = (userData['city'] as String?) ?? '';

    // Collect candidate UIDs from events user attended/created
    final eventsSnap = await _db
        .collection('events')
        .where('attendeeUids', arrayContains: uid)
        .limit(10)
        .get();

    final candidateUids = <String>{};
    for (final doc in eventsSnap.docs) {
      final attendees = List<String>.from(doc.data()['attendeeUids'] ?? []);
      candidateUids.addAll(attendees);
    }

    // Also add by shared interests (fetch a small sample of users)
    if (myInterests.isNotEmpty) {
      final interestSnap = await _db
          .collection('users')
          .where('interests', arrayContainsAny: myInterests.take(10).toList())
          .limit(30)
          .get();
      for (final d in interestSnap.docs) {
        candidateUids.add(d.id);
      }
    }

    candidateUids.removeAll(excluded);
    if (candidateUids.isEmpty) return [];

    // Fetch profiles and score
    final suggestions = <Map<String, dynamic>>[];
    final batches = _chunkList(candidateUids.toList(), 10);

    for (final batch in batches) {
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final theirInterests = List<String>.from(data['interests'] ?? []);
        final sharedInterests =
            myInterests.where((i) => theirInterests.contains(i)).length;
        final sameCity = myCity.isNotEmpty && (data['city'] ?? '') == myCity;

        final score = sharedInterests * 2 + (sameCity ? 1 : 0);

        suggestions.add({
          'uid': doc.id,
          'displayName': data['displayName'] ?? 'User',
          'city': data['city'] ?? '',
          'photoUrl': data['profileImageUrl'] ?? data['photoUrl'] ?? '',
          'interests': theirInterests,
          'bio': data['bio'] ?? '',
          'score': score,
        });
      }
    }

    suggestions.sort((a, b) => (b['score'] as int) - (a['score'] as int));
    return suggestions.take(10).toList();
  }

  static List<List<T>> _chunkList<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(
          list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}
