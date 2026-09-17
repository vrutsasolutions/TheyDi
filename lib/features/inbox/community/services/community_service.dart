import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/community_model.dart';

/// Handles joining, leaving, and requesting to join Communities.
///
/// Data shape:
///  - `communities/{id}`                                  — the community doc
///  - `communities/{id}/joinRequests/{uid}`                — pending requests,
///     visible to whoever manages the community
///  - `users/{uid}/communityRequests/{communityId}`        — mirror of the
///     same request, so "my requested communities" is a cheap direct query
///     instead of a collection-group query across every community.
class CommunityService {
  CommunityService._();

  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Instantly joins an open (non-approval-gated) community.
  static Future<void> joinCommunity(
    CommunityModel community, {
    required String userName,
  }) async {
    if (_uid.isEmpty) throw Exception('Not signed in. Please log in and try again.');
    await _db.collection('communities').doc(community.id).update({
      'memberUids': FieldValue.arrayUnion([_uid]),
      'memberNames': FieldValue.arrayUnion([userName]),
    });
  }

  static Future<void> leaveCommunity(CommunityModel community) async {
    if (_uid.isEmpty) return;
    // NOTE: mirrors the same index-paired-arrays approach CircleModel uses
    // for memberUids/memberNames. Removing by value from memberNames only
    // works cleanly if names are unique-ish; if two members share a name,
    // arrayRemove could in principle strip the wrong entry. This is an
    // existing pattern from Circles, not something introduced here.
    final doc = await _db.collection('communities').doc(community.id).get();
    final data = doc.data();
    String? myName;
    if (data != null) {
      final uids = List<String>.from(data['memberUids'] ?? []);
      final names = List<String>.from(data['memberNames'] ?? []);
      final idx = uids.indexOf(_uid);
      if (idx != -1 && idx < names.length) myName = names[idx];
    }
    await _db.collection('communities').doc(community.id).update({
      'memberUids': FieldValue.arrayRemove([_uid]),
      if (myName != null) 'memberNames': FieldValue.arrayRemove([myName]),
    });
  }

  /// Sends a join request for an approval-gated community. Writes the
  /// mirrored pair of documents described above.
  static Future<void> requestToJoin(
    CommunityModel community, {
    required String userName,
  }) async {
    if (_uid.isEmpty) return;
    final request = CommunityJoinRequest(
      communityId: community.id,
      communityName: community.name,
      uid: _uid,
      userName: userName,
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(
      _db
          .collection('communities')
          .doc(community.id)
          .collection('joinRequests')
          .doc(_uid),
      request.toFirestoreMap(),
    );
    batch.set(
      _db
          .collection('users')
          .doc(_uid)
          .collection('communityRequests')
          .doc(community.id),
      request.toFirestoreMap(),
    );
    await batch.commit();
  }

  static Future<void> cancelJoinRequest(String communityId) async {
    if (_uid.isEmpty) return;
    final batch = _db.batch();
    batch.delete(_db
        .collection('communities')
        .doc(communityId)
        .collection('joinRequests')
        .doc(_uid));
    batch.delete(_db
        .collection('users')
        .doc(_uid)
        .collection('communityRequests')
        .doc(communityId));
    await batch.commit();
  }

  /// Approves a pending request (called by a community admin/creator) —
  /// adds the requester to memberUids/memberNames and clears the request
  /// pair.
  static Future<void> approveJoinRequest({
    required String communityId,
    required String requesterUid,
    required String requesterName,
  }) async {
    final batch = _db.batch();
    batch.update(_db.collection('communities').doc(communityId), {
      'memberUids': FieldValue.arrayUnion([requesterUid]),
      'memberNames': FieldValue.arrayUnion([requesterName]),
    });
    batch.delete(_db
        .collection('communities')
        .doc(communityId)
        .collection('joinRequests')
        .doc(requesterUid));
    batch.delete(_db
        .collection('users')
        .doc(requesterUid)
        .collection('communityRequests')
        .doc(communityId));
    await batch.commit();
  }

  static Future<void> declineJoinRequest({
    required String communityId,
    required String requesterUid,
  }) async {
    final batch = _db.batch();
    batch.delete(_db
        .collection('communities')
        .doc(communityId)
        .collection('joinRequests')
        .doc(requesterUid));
    batch.delete(_db
        .collection('users')
        .doc(requesterUid)
        .collection('communityRequests')
        .doc(communityId));
    await batch.commit();
  }

  /// Directly adds someone to the community (used by CommunityInfoScreen's
  /// "Add Members" sheet — the creator/admin picking specific people
  /// rather than waiting for them to join or request themselves).
  static Future<void> addMemberToCommunity({
    required String communityId,
    required String userUid,
    required String userName,
  }) async {
    await _db.collection('communities').doc(communityId).update({
      'memberUids': FieldValue.arrayUnion([userUid]),
      'memberNames': FieldValue.arrayUnion([userName]),
    });
  }

  /// Removes a specific member (used by CommunityInfoScreen when an
  /// admin/creator removes someone, as opposed to leaveCommunity which is
  /// the member removing themselves).
  static Future<void> removeMemberFromCommunity({
    required String communityId,
    required String userUid,
    required String userName,
  }) async {
    await _db.collection('communities').doc(communityId).update({
      'memberUids': FieldValue.arrayRemove([userUid]),
      'memberNames': FieldValue.arrayRemove([userName]),
    });
  }
}