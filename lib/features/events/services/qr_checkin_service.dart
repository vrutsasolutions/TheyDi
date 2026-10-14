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

// ── Token + booking reference result ──────────────────────────────────────────

class TokenResult {
  final String checkInToken;
  final String bookingRef;   // e.g. "TDI-A3K8F2"

  const TokenResult({required this.checkInToken, required this.bookingRef});
}

// ── Token payload stored in QR ─────────────────────────────────────────────────
// The QR encodes ONLY this lightweight string — no PII.
// Format for paid events:  "theydi:checkin:<32-char-hex-token>"
// Format for free events:  "theydi:checkin:<32-char-hex-token>"  (same)
// The server resolves eventId + bookingId + userId from the token.

class QrCheckInService {
  QrCheckInService._();

  static final _firestore  = FirebaseFirestore.instance;
  static final _functions  = FirebaseFunctions.instanceFor(region: 'asia-south1');

  // ── Build the string that goes inside the QR code ─────────────────────────
  // Called by AttendeeQrScreen after fetching the token from Firestore.
  static String buildQrPayload(String checkInToken) =>
      'theydi:checkin:$checkInToken';

  // ── Fetch (or generate) the check-in token ───────────────────────────────
  //
  // Two paths depending on whether the event is paid or free:
  //
  // PAID EVENT (bookingId is non-empty):
  //   1. Look up bookings/{bookingId} — must be confirmed & match eventId.
  //   2. If checkInToken already exists on the booking doc, return it.
  //   3. Otherwise call generateCheckInToken Cloud Function.
  //
  // FREE EVENT (bookingId is empty string ''):
  //   1. Look up events/{eventId}/attendeeTokens/{userId}.
  //   2. If token already exists there, return it.
  //   3. Otherwise call generateFreeEventToken Cloud Function which creates
  //      the token and writes it back to attendeeTokens/{userId}.
  //
  static Future<TokenResult> getOrCreateToken({
    required String eventId,
    required String bookingId,
    required String userId,
  }) async {
    if (bookingId.isNotEmpty) {
      return _getOrCreatePaidToken(
          eventId: eventId, bookingId: bookingId, userId: userId);
    } else {
      return _getOrCreateFreeToken(eventId: eventId, userId: userId);
    }
  }

  // ── Paid event token ──────────────────────────────────────────────────────
  static Future<TokenResult> _getOrCreatePaidToken({
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
      throw Exception('Booking does not match your account.');
    }
    if (data['status'] != 'confirmed') {
      throw Exception('Booking is not confirmed yet.');
    }

    final existingToken = data['checkInToken'] as String?;
    final existingRef   = data['bookingRef'] as String?;
    if (existingToken != null && existingToken.isNotEmpty &&
        existingRef != null && existingRef.isNotEmpty) {
      return TokenResult(checkInToken: existingToken, bookingRef: existingRef);
    }

    // 2. Generate via Cloud Function (creates token + bookingRef, or migrates)
    final callable = _functions.httpsCallable('generateCheckInToken');
    final result   = await callable.call<Map<String, dynamic>>({
      'eventId'  : eventId,
      'bookingId': bookingId,
    });

    final token = result.data['checkInToken'] as String?;
    final ref   = result.data['bookingRef']   as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Server did not return a token.');
    }
    return TokenResult(
      checkInToken: token,
      bookingRef: ref ?? '',
    );
  }

  // ── Free event token ──────────────────────────────────────────────────────
  // For free events no booking document exists. The token is stored in
  // events/{eventId}/attendeeTokens/{userId} by the Cloud Function.
  //
  // Flow:
  //   1. Fast-path: check if token already exists in attendeeTokens (read-only).
  //   2. If not, call generateFreeEventToken CF which creates the token
  //      server-side and writes to both attendeeTokens and checkIns.
  //
  // Client-side writes are NOT used — all mutations go through Cloud Functions
  // so we don't need broad Firestore write rules on these sub-collections.
  static Future<TokenResult> _getOrCreateFreeToken({
    required String eventId,
    required String userId,
  }) async {
    // 1. Fast-path: read existing token (Firestore rules allow attendee to
    //    read their own attendeeTokens/{userId} doc).
    try {
      final tokenRef = _firestore
          .collection('events')
          .doc(eventId)
          .collection('attendeeTokens')
          .doc(userId);

      final tokenDoc = await tokenRef.get();
      if (tokenDoc.exists) {
        final existingToken = tokenDoc.data()?['checkInToken'] as String?;
        final existingRef   = tokenDoc.data()?['bookingRef']   as String?;
        if (existingToken != null && existingToken.isNotEmpty &&
            existingRef != null && existingRef.isNotEmpty) {
          return TokenResult(checkInToken: existingToken, bookingRef: existingRef);
        }
      }
    } catch (_) {
      // If the fast-path read fails (e.g. doc doesn't exist yet, or
      // rules haven't propagated), fall through to the CF path.
    }

    // 2. Generate via Cloud Function (server-side write to both
    //    attendeeTokens/{userId} and checkIns/{userId}).
    final callable = _functions.httpsCallable('generateFreeEventToken');
    final result = await callable.call<Map<String, dynamic>>({
      'eventId': eventId,
      'userId': userId,
    });

    final token = result.data['checkInToken'] as String?;
    final ref   = result.data['bookingRef']   as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Server did not return a token.');
    }
    return TokenResult(
      checkInToken: token,
      bookingRef: ref ?? '',
    );
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
  //
  // Reads the event doc's attendeeUids array length. The event doc is publicly
  // readable, so this avoids a bookings query that would fail Firestore rules
  // (bookings rules require the requester to be userId/hostUid/etc., which a
  // collection-wide query can't satisfy).
  //
  // For paid events the host may also have free-event attendees mixed in via
  // attendeeUids, so this gives the true total of everyone who joined.
  static Future<int> confirmedAttendeeCount(String eventId) async {
    final eventDoc = await _firestore
        .collection('events')
        .doc(eventId)
        .get();

    if (!eventDoc.exists) return 0;
    final data = eventDoc.data()!;
    final attendeeUids = data['attendeeUids'] as List<dynamic>?;
    return attendeeUids?.length ?? 0;
  }
}