import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { pending, confirmed, cancelled, refunded }

class BookingModel {
  final String id;
  final String eventId;
  final String eventTitle;
  final String userId;
  final String userName;
  final String hostUid;
  final double amount;
  final double platformFee;
  final double totalAmount;
  final BookingStatus status;
  final String paymentMethod;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  const BookingModel({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.userId,
    required this.userName,
    required this.hostUid,
    required this.amount,
    this.platformFee = 0,
    required this.totalAmount,
    this.status = BookingStatus.pending,
    this.paymentMethod = 'mock',
    this.transactionId,
    required this.createdAt,
    this.confirmedAt,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Helper function to parse DateTime from either Timestamp or String
    DateTime _parseDateTime(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return DateTime.now();
        }
      } else if (dateValue is DateTime) {
        return dateValue;
      }
      return DateTime.now();
    }
    
    // Helper function to parse nullable DateTime
    DateTime? _parseNullableDateTime(dynamic dateValue) {
      if (dateValue == null) return null;
      
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return null;
        }
      } else if (dateValue is DateTime) {
        return dateValue;
      }
      return null;
    }
    
    return BookingModel(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      eventTitle: data['eventTitle'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      hostUid: data['hostUid'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      platformFee: (data['platformFee'] ?? 0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => BookingStatus.pending,
      ),
      paymentMethod: data['paymentMethod'] ?? 'mock',
      transactionId: data['transactionId'],
      createdAt: _parseDateTime(data['createdAt']),
      confirmedAt: _parseNullableDateTime(data['confirmedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'eventId': eventId,
      'eventTitle': eventTitle,
      'userId': userId,
      'userName': userName,
      'hostUid': hostUid,
      'amount': amount,
      'platformFee': platformFee,
      'totalAmount': totalAmount,
      'status': status.name,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'confirmedAt':
          confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
    };
  }

  /// Calculate platform fee (5% of event price)
  static double calculatePlatformFee(double eventPrice) {
    return (eventPrice * 0.05).roundToDouble();
  }

  /// Calculate total including platform fee
  static double calculateTotal(double eventPrice) {
    return eventPrice + calculatePlatformFee(eventPrice);
  }

  /// Status display helpers
  String get statusLabel {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.refunded:
        return 'Refunded';
    }
  }

  bool get isConfirmed => status == BookingStatus.confirmed;
  bool get isPending => status == BookingStatus.pending;
}