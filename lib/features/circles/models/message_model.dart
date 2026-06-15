import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String circleId;
  final String senderUid;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final List<String> readBy;   // delivered = stored in Firestore
  final List<String> seenBy;   // seen = opened the chat

  const MessageModel({
    required this.id,
    required this.circleId,
    required this.senderUid,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.readBy = const [],
    this.seenBy = const [],
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      circleId: data['circleId'] ?? '',
      senderUid: data['senderUid'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      readBy: List<String>.from(data['readBy'] ?? []),
      seenBy: List<String>.from(data['seenBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'circleId': circleId,
      'senderUid': senderUid,
      'senderName': senderName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'readBy': readBy,
      'seenBy': seenBy,
    };
  }

  bool isMine(String uid) => senderUid == uid;
  bool isReadBy(String uid) => readBy.contains(uid);
  bool isSeenBy(String uid) => seenBy.contains(uid);

  /// Tick status for MY messages:
  /// ✓✓ blue  = at least one other member has seen it
  /// ✓✓ grey  = delivered (in readBy) but not yet seen
  /// ✓  grey  = just sent (only sender in readBy)
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
      final displayHour =
          hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${createdAt.day}/${createdAt.month}';
  }
}

enum ReadReceiptStatus { sent, delivered, seen }