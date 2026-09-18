import 'package:cloud_firestore/cloud_firestore.dart';

/// Communities are open, interest-based groups anyone can create — distinct
/// from Circles, which are locked to the creator of the experience they're
/// attached to. See CircleModel for the comparison.
class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String category; // e.g. 'Tech', 'Design', 'Food', 'Fitness'...
  final String creatorUid;
  final String creatorName;
  final List<String> memberUids;
  final List<String> memberNames;
  final String? lastMessage;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final String? coverImageUrl;

  // If true, joining requires the creator/admins to approve a request
  // first (tracked in the `joinRequests` subcollection). If false, tapping
  // Join adds the user to `memberUids` immediately.
  final bool requiresApproval;
  final String type; // 'Social' | 'Professional'
  final String city;
  final List<String> interests;

  const CommunityModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.category,
    required this.creatorUid,
    required this.creatorName,
    this.memberUids = const [],
    this.memberNames = const [],
    this.lastMessage,
    this.lastMessageSender,
    this.lastMessageAt,
    required this.createdAt,
    this.coverImageUrl,
    this.requiresApproval = false,
    this.type = 'Social',
    this.city = '',
    this.interests = const [],
  });

  factory CommunityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      creatorUid: data['creatorUid'] ?? '',
      creatorName: data['creatorName'] ?? '',
      memberUids: List<String>.from(data['memberUids'] ?? []),
      memberNames: List<String>.from(data['memberNames'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageSender: data['lastMessageSender'],
      lastMessageAt: data['lastMessageAt'] != null
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      coverImageUrl: data['coverImageUrl'],
      requiresApproval: data['requiresApproval'] ?? false,
      type: data['type'] ?? 'Social',
      city: data['city'] ?? '',
      interests: List<String>.from(data['interests'] ?? []),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'creatorUid': creatorUid,
      'creatorName': creatorName,
      'memberUids': memberUids,
      'memberNames': memberNames,
      'lastMessage': lastMessage,
      'lastMessageSender': lastMessageSender,
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'coverImageUrl': coverImageUrl,
      'requiresApproval': requiresApproval,
      'type': type,
      'city': city,
      'interests': interests,
    };
  }

  int get memberCount => memberUids.toSet().length;
  bool isMember(String uid) => memberUids.contains(uid);

  // Deduplicated member map: uid → name — mirrors CircleModel.memberMap so
  // the info screen can render a member list without a Firestore lookup
  // per member.
  Map<String, String> get memberMap {
    final map = <String, String>{};
    for (int i = 0; i < memberUids.length; i++) {
      final uid = memberUids[i];
      if (!map.containsKey(uid)) {
        map[uid] = i < memberNames.length ? memberNames[i] : 'Member';
      }
    }
    return map;
  }

  String get initials {
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

/// A pending request to join an approval-gated community. Lives at
/// `communities/{communityId}/joinRequests/{uid}` so the community's
/// creator/admins can see and act on it, alongside a mirrored doc at
/// `users/{uid}/communityRequests/{communityId}` so the requester can
/// cheaply query "my pending requests" without a collection group query.
class CommunityJoinRequest {
  final String communityId;
  final String communityName;
  final String uid;
  final String userName;
  final DateTime createdAt;
  final String status; // 'pending' | 'accepted' | 'declined'

  const CommunityJoinRequest({
    required this.communityId,
    required this.communityName,
    required this.uid,
    required this.userName,
    required this.createdAt,
    this.status = 'pending',
  });

  factory CommunityJoinRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityJoinRequest(
      communityId: data['communityId'] ?? '',
      communityName: data['communityName'] ?? '',
      uid: data['uid'] ?? '',
      userName: data['userName'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'communityId': communityId,
      'communityName': communityName,
      'uid': uid,
      'userName': userName,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }
}