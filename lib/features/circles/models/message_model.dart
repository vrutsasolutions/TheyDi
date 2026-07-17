import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;

  final String? mediaUrl;
  final String? mediaType; // 'image' | 'video' | 'audio'

  final String circleId;
  final String senderUid;
  final String senderName;
  final String text;

  final DateTime createdAt;
  final List<String> readBy;
  final List<String> seenBy;

  const MessageModel({
    required this.id,
    required this.circleId,
    required this.senderUid,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.mediaUrl,
    this.mediaType,
    this.readBy = const [],
    this.seenBy = const [],
  });

  // ✅ FROM FIRESTORE (FIXED)
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MessageModel(
      id: doc.id,
      circleId: data['circleId'] ?? '',
      senderUid: data['senderUid'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      mediaUrl: data['mediaUrl'], // ✅ FIXED
      mediaType: data['mediaType'], // ✅ FIXED
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      readBy: List<String>.from(data['readBy'] ?? []),
      seenBy: List<String>.from(data['seenBy'] ?? []),
    );
  }

  // ✅ TO FIRESTORE (FIXED)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'circleId': circleId,
      'senderUid': senderUid,
      'senderName': senderName,
      'text': text,

      'mediaUrl': mediaUrl, // ✅ FIXED
      'mediaType': mediaType, // ✅ FIXED

      'createdAt': Timestamp.fromDate(createdAt),
      'readBy': readBy,
      'seenBy': seenBy,
    };
  }

  bool isMine(String uid) => senderUid == uid;
  bool isReadBy(String uid) => readBy.contains(uid);
  bool isSeenBy(String uid) => seenBy.contains(uid);

  ReadReceiptStatus receiptStatus(String myUid, List<String> allMemberUids) {
    final others = allMemberUids.where((u) => u != myUid).toList();
    if (others.isEmpty) return ReadReceiptStatus.sent;

    final anyoneSeen = others.any((u) => seenBy.contains(u));
    if (anyoneSeen) return ReadReceiptStatus.seen;

    final anyoneDelivered = others.any((u) => readBy.contains(u));
    if (anyoneDelivered) return ReadReceiptStatus.delivered;

    return ReadReceiptStatus.sent;
  }

  String get timeLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';

    if (diff.inDays < 1) {
      final hour = createdAt.hour;
      final minute = createdAt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }

    if (diff.inDays < 7) return '${diff.inDays}d';

    return '${createdAt.day}/${createdAt.month}';
  }
}

enum ReadReceiptStatus { sent, delivered, seen }
