import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String eventId;
  final String eventTitle;
  final String reviewerUid;
  final String reviewerName;
  final String hostUid;
  final String hostName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.reviewerUid,
    required this.reviewerName,
    required this.hostUid,
    required this.hostName,
    required this.rating,
    this.comment = '',
    required this.createdAt,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      eventTitle: data['eventTitle'] ?? '',
      reviewerUid: data['reviewerUid'] ?? '',
      reviewerName: data['reviewerName'] ?? '',
      hostUid: data['hostUid'] ?? '',
      hostName: data['hostName'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'eventId': eventId,
      'eventTitle': eventTitle,
      'reviewerUid': reviewerUid,
      'reviewerName': reviewerName,
      'hostUid': hostUid,
      'hostName': hostName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Star display helper
  String get ratingLabel {
    if (rating >= 4.5) return 'Amazing';
    if (rating >= 3.5) return 'Great';
    if (rating >= 2.5) return 'Good';
    if (rating >= 1.5) return 'Okay';
    return 'Poor';
  }
}