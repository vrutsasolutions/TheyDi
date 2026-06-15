import 'package:cloud_firestore/cloud_firestore.dart';

class CircleModel {
  final String id;
  final String name;
  final String description;
  final String creatorUid;
  final String creatorName;
  final List<String> memberUids;
  final List<String> memberNames;
  final String? lastMessage;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final String type;        // 'event' | 'custom'
  final String? eventId;
  final String? profileImageUrl;

  const CircleModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.creatorUid,
    required this.creatorName,
    this.memberUids = const [],
    this.memberNames = const [],
    this.lastMessage,
    this.lastMessageSender,
    this.lastMessageAt,
    required this.createdAt,
    this.type = 'custom',
    this.eventId,
    this.profileImageUrl,
  });

  factory CircleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CircleModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
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
      type: data['type'] ?? 'custom',
      eventId: data['eventId'],
      profileImageUrl: data['profileImageUrl'],
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name,
      'description': description,
      'creatorUid': creatorUid,
      'creatorName': creatorName,
      'memberUids': memberUids,
      'memberNames': memberNames,
      'lastMessage': lastMessage,
      'lastMessageSender': lastMessageSender,
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'type': type,
      'eventId': eventId,
      'profileImageUrl': profileImageUrl,
    };
  }

  // Deduplicated member count
  int get memberCount => memberUids.toSet().length;
  bool get isEventCircle => type == 'event';
  bool isMember(String uid) => memberUids.contains(uid);

  String get initials {
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // Deduplicated member map: uid → name
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
}