import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String venue;
  final String city;
  final double latitude;
  final double longitude;
  final DateTime dateTime;
  final int maxAttendees;
  final String creatorUid;
  final String creatorName;
  final String? imageUrl;
  final List<String> imageUrls;
  final List<String> tags;
  final List<String> attendeeUids;
  final List<String> pendingUids;
  final List<String> approvedPendingPaymentUids;
  final bool isFree;
  final double price;
  final DateTime? createdAt;
  final int durationHours;
  final String ageGroup;
  final String status;
  final String? additionalAddress;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.venue,
    required this.city,
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.dateTime,
    required this.maxAttendees,
    required this.creatorUid,
    required this.creatorName,
    this.imageUrl,
    this.imageUrls = const [],
    this.tags = const [],
    this.attendeeUids = const [],
    this.pendingUids = const [],
    this.approvedPendingPaymentUids = const [],
    this.isFree = false,
    this.price = 0.0,
    this.createdAt,
    this.durationHours = 0,
    this.ageGroup = '',
    this.status = 'upcoming',
    this.additionalAddress,
  });

  // ── Computed getters ────────────────────────────────────────────────────────

  DateTime get endTime {
    if (durationHours > 0) return dateTime.add(Duration(hours: durationHours));
    return dateTime.add(const Duration(hours: 2));
  }

  bool get isExpired => endTime.isBefore(DateTime.now());

  String get effectiveStatus {
    final now = DateTime.now();
    if (endTime.isBefore(now)) return 'completed';
    if (dateTime.isBefore(now)) return 'ongoing';
    return 'upcoming';
  }

  bool get isUpcoming => effectiveStatus == 'upcoming';
  bool get isOngoing => effectiveStatus == 'ongoing';
  bool get isCompleted => effectiveStatus == 'completed';

  List<String> get allImages {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (imageUrl != null && imageUrl!.isNotEmpty) return [imageUrl!];
    return [];
  }

  String get location => venue;
  String get organizerId => creatorUid;
  String get organizerName => creatorName;
  int get currentAttendees => attendeeUids.length;
  bool get isFull => currentAttendees >= maxAttendees;
  int get spotsLeft => maxAttendees - currentAttendees;
  int get pendingCount => pendingUids.length;
  bool isPending(String uid) => pendingUids.contains(uid);
  bool isApprovedPendingPayment(String uid) =>
      approvedPendingPaymentUids.contains(uid);

  // ── Safe date parser — handles Timestamp, String, int (millis), and null ───
  static DateTime _parseDate(dynamic value, DateTime fallback) {
    if (value == null) return fallback;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return fallback;
  }

  static DateTime? _parseDateNullable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  // ── fromFirestore ───────────────────────────────────────────────────────────
  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      venue: data['venue'] ?? '',
      city: data['city'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),

      // ← KEY FIX: safe parsing handles both Timestamp and String
      dateTime: _parseDate(data['dateTime'], DateTime.now()),
      createdAt: _parseDateNullable(data['createdAt']),

      maxAttendees: data['maxAttendees'] ?? 0,
      creatorUid: data['creatorUid'] ?? '',
      creatorName: data['creatorName'] ?? '',
      imageUrl: data['imageUrl'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
      attendeeUids: List<String>.from(data['attendeeUids'] ?? []),
      pendingUids: List<String>.from(data['pendingUids'] ?? []),
      approvedPendingPaymentUids:
          List<String>.from(data['approvedPendingPaymentUids'] ?? []),
      isFree: data['isFree'] ?? true,
      price: (data['price'] ?? 0.0).toDouble(),
      durationHours: data['durationHours'] ?? 0,
      ageGroup: data['ageGroup'] ?? '',
      status: data['status'] ?? 'upcoming',
      additionalAddress: data['additionalAddress'],
    );
  }

  // ── toFirestoreMap ──────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestoreMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'venue': venue,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'dateTime': Timestamp.fromDate(dateTime),  // always write as Timestamp
      'maxAttendees': maxAttendees,
      'creatorUid': creatorUid,
      'organizerUid': creatorUid,   // ← write BOTH so rules & queries work
      'creatorName': creatorName,
      'organizerName': creatorName, // ← write BOTH for consistency
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'tags': tags,
      'attendeeUids': attendeeUids,
      'additionalAddress': additionalAddress,
      'pendingUids': pendingUids,
      'approvedPendingPaymentUids': approvedPendingPaymentUids,
      'isFree': isFree,
      'price': price,
      'createdAt': FieldValue.serverTimestamp(),
      'durationHours': durationHours,
      'ageGroup': ageGroup,
      'status': status,
      'endTime': Timestamp.fromDate(endTime),
      'payoutProcessed': false,
    };
  }

  // ── Sample events (for UI testing) ─────────────────────────────────────────
  static List<EventModel> sampleEvents = [
    EventModel(
      id: '1',
      title: 'Sunset Rooftop Mixer',
      description: 'Join us for an evening of networking and fun on the rooftop.',
      category: 'Social',
      venue: 'Sky Lounge, MG Road',
      city: 'Bangalore',
      latitude: 12.9716,
      longitude: 77.5946,
      dateTime: DateTime.now().add(const Duration(days: 2)),
      maxAttendees: 50,
      creatorUid: 'org1',
      creatorName: 'Arjun S',
      attendeeUids: List.generate(32, (i) => 'user$i'),
      isFree: false,
      price: 299,
      tags: ['networking', 'rooftop'],
      durationHours: 3,
      ageGroup: 'Young Adults (18–25)',
    ),
    EventModel(
      id: '2',
      title: 'Tech Founders Brunch',
      description: 'Casual Sunday brunch for startup founders.',
      category: 'Professional',
      venue: 'The Brew Room, Koramangala',
      city: 'Bangalore',
      latitude: 12.9352,
      longitude: 77.6245,
      dateTime: DateTime.now().add(const Duration(days: 5)),
      maxAttendees: 30,
      creatorUid: 'org2',
      creatorName: 'Priya M',
      attendeeUids: List.generate(28, (i) => 'user$i'),
      isFree: false,
      price: 499,
      tags: ['startup', 'tech'],
      durationHours: 2,
      ageGroup: 'Adults (25–35)',
    ),
  ];
}