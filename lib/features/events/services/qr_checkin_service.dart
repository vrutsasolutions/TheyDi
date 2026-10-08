import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

// ── QR Check-in data model ─────────────────────────────────────────────────────

class CheckInResult {
  final bool success;
  final String status; // 'checked_in' | 'already_checked_in' | 'invalid'
  final String? attendeeName;
  final String? eventTitle;
  final String? checkedInAt;   // formatted time string from server
  final String? errorMessage;

  const CheckInResult({
    required this.success,
    required this.status,
    this.attendeeName,
    this.eventTitle,
    this.checkedInAt,
    this.errorMessage,
  });

  bool get isAlreadyCheckedIn => status == 'already_checked_in';
  bool get isInvalid           => status == 'invalid';
}

// ── Token payload stored in QR ─────────────────────────────────────────────────
// The QR encodes ONLY this lightweight string — no PII.
// Format:  "theydi:checkin:<checkInToken>"
// The server resolves eventId + bookingId + userId from the token.

class QrCheckInService {
  QrCheckInService._();

  static final _firestore  = FirebaseFirestore.instance;
  static final _functions  = FirebaseFunctions.instanceFor(region: 'asia-south1');

  // ── Build the string that goes inside the QR code ─────────────────────────
  // Called by AttendeeQrScreen after fetching the token from Firestore.
  static String buildQrPayload(String checkInToken) =>
      'theydi:checkin:$checkInToken';

  // ── Fetch (or generate) the check-in token for a confirmed booking ────────
  //
  // Flow:
  //   1. Look up bookings/{bookingId} — must be confirmed & match eventId.
  //   2. If checkInToken already exists on the booking doc, return it.
  //   3. Otherwise call the Cloud Function `generateCheckInToken` which
  //      creates the token server-side and writes it back to the booking.
  //
  static Future<String> getOrCreateToken({
    required String eventId,
    required String bookingId,
    required String userId,
  }) async {
    // 1. Check Firestore first (fast path — token already created)
    final bookingDoc = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();

    if (!bookingDoc.exists) {
      throw Exception('Booking not found.');
    }

    final data = bookingDoc.data()!;

    // Safety: booking must belong to this user and event
    if (data['userId'] != userId || data['eventId'] != eventId) {
      throw Exception('Booking does not match.');
    }
    if (data['status'] != 'confirmed') {
      throw Exception('Booking is not confirmed.');
    }

    final existingToken = data['checkInToken'] as String?;
    if (existingToken != null && existingToken.isNotEmpty) {
      return existingToken;
    }

    // 2. Generate via Cloud Function
    final callable = _functions.httpsCallable('generateCheckInToken');
    final result   = await callable.call<Map<String, dynamic>>({
      'eventId'  : eventId,
      'bookingId': bookingId,
    });

    final token = result.data['checkInToken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Server did not return a token.');
    }
    return token;
  }

  // ── Validate a scanned QR payload (host action) ───────────────────────────
  //
  // Calls the Cloud Function `validateCheckIn` which:
  //   • Parses the token
  //   • Verifies it belongs to this eventId
  //   • Checks booking status (confirmed, not cancelled/refunded)
  //   • Checks duplicate scan
  //   • Writes checkedIn = true, checkedInAt, checkedInBy to Firestore
  //
  static Future<CheckInResult> validateAndCheckIn({
    required String qrPayload,
    required String eventId,
    required String hostUid,
  }) async {
    try {
      final callable = _functions.httpsCallable('validateCheckIn');
      final result   = await callable.call<Map<String, dynamic>>({
        'qrPayload': qrPayload,
        'eventId'  : eventId,
        'hostUid'  : hostUid,
      });

      final d = Map<String, dynamic>.from(result.data);
      return CheckInResult(
        success      : d['success']      == true,
        status       : d['status']       as String? ?? 'invalid',
        attendeeName : d['attendeeName'] as String?,
        eventTitle   : d['eventTitle']   as String?,
        checkedInAt  : d['checkedInAt']  as String?,
        errorMessage : d['errorMessage'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      return CheckInResult(
        success      : false,
        status       : 'invalid',
        errorMessage : e.message ?? 'Validation failed.',
      );
    } catch (e) {
      return CheckInResult(
        success      : false,
        status       : 'invalid',
        errorMessage : 'An unexpected error occurred.',
      );
    }
  }

  // ── Real-time attendance count stream (for host scanner screen) ───────────
  //
  // Listens to the event doc's attendeeUids length + checks the checkIns
  // sub-collection count so the host sees live "Checked In: X / Y".
  //
  static Stream<Map<String, int>> attendanceStream(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('checkIns')
        .snapshots()
        .map((snap) {
      final checkedIn = snap.docs
          .where((d) => d.data()['checkedIn'] == true)
          .length;
      return {'checkedIn': checkedIn};
    });
  }

  // ── Fetch total confirmed attendee count for an event ─────────────────────
  static Future<int> confirmedAttendeeCount(String eventId) async {
    final snap = await _firestore
        .collection('bookings')
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: 'confirmed')
        .count()
        .get();
    return snap.count ?? 0;
  }
}