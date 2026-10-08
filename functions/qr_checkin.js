// ─────────────────────────────────────────────────────────────────────────────
// QR Check-in Cloud Functions
//
// Exports:
//   generateCheckInToken  — called by attendee after booking confirmed
//   validateCheckIn       — called by host when scanning attendee QR
//
// Both functions run on admin SDK only — clients cannot write checkedIn
// directly to Firestore.
//
// Firestore paths used:
//   bookings/{bookingId}                      — existing collection
//     .checkInToken      (string, written here)
//     .checkedIn         (bool,   written on scan)
//     .checkedInAt       (Timestamp)
//     .checkedInBy       (string, host uid)
//
//   events/{eventId}/checkIns/{bookingId}     — new sub-collection
//     eventId, bookingId, attendeeUserId,
//     checkInToken, checkedIn, checkedInAt,
//     checkedInBy, createdAt
// ─────────────────────────────────────────────────────────────────────────────

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin  = require("firebase-admin");
const crypto = require("crypto");

const db     = admin.firestore();
const REGION = "asia-south1";

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — generate a cryptographically random 32-char hex token
// ─────────────────────────────────────────────────────────────────────────────
function _randomToken() {
  return crypto.randomBytes(16).toString("hex"); // 32 hex chars
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — format a Firestore Timestamp (or Date) as "h:mm AM/PM"
// ─────────────────────────────────────────────────────────────────────────────
function _formatTime(ts) {
  const date = ts && ts.toDate ? ts.toDate() : new Date();
  let hours   = date.getHours();
  const mins  = String(date.getMinutes()).padStart(2, "0");
  const ampm  = hours >= 12 ? "PM" : "AM";
  hours       = hours % 12 || 12;
  return `${hours}:${mins} ${ampm}`;
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. generateCheckInToken
//
// Called by: AttendeeQrScreen (Flutter) after confirming a booking.
// Auth:      Must be signed in. Must own the booking.
//
// Input:  { eventId: string, bookingId: string }
// Output: { checkInToken: string }
// ─────────────────────────────────────────────────────────────────────────────
exports.generateCheckInToken = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const { eventId, bookingId } = request.data;
  if (!eventId || !bookingId) {
    throw new HttpsError("invalid-argument", "eventId and bookingId are required.");
  }

  const bookingRef = db.collection("bookings").doc(bookingId);
  const bookingDoc = await bookingRef.get();

  if (!bookingDoc.exists) {
    throw new HttpsError("not-found", "Booking not found.");
  }

  const booking = bookingDoc.data();

  // Security checks
  if (booking.userId !== uid) {
    throw new HttpsError("permission-denied", "This booking does not belong to you.");
  }
  if (booking.eventId !== eventId) {
    throw new HttpsError("invalid-argument", "Booking does not match this event.");
  }
  if (booking.status !== "confirmed") {
    throw new HttpsError("failed-precondition", "Booking is not confirmed.");
  }

  // Return existing token if already generated (idempotent)
  if (booking.checkInToken) {
    return { checkInToken: booking.checkInToken };
  }

  // Generate new token
  const token = _randomToken();
  const now   = admin.firestore.FieldValue.serverTimestamp();

  // Write token to booking doc
  await bookingRef.update({ checkInToken: token });

  // Create the checkIns sub-collection document (checkedIn = false initially)
  const checkInRef = db
    .collection("events")
    .doc(eventId)
    .collection("checkIns")
    .doc(bookingId);

  await checkInRef.set({
    eventId,
    bookingId,
    attendeeUserId : uid,
    checkInToken   : token,
    checkedIn      : false,
    checkedInAt    : null,
    checkedInBy    : null,
    createdAt      : now,
  }, { merge: true });

  return { checkInToken: token };
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. validateCheckIn
//
// Called by: HostScannerScreen (Flutter) after host scans a QR.
// Auth:      Must be signed in as the event host.
//
// Input:  { qrPayload: string, eventId: string, hostUid: string }
//         qrPayload format: "theydi:checkin:<token>"
//
// Output (success):
//   { success: true, status: 'checked_in', attendeeName, eventTitle, checkedInAt }
//
// Output (already checked in):
//   { success: false, status: 'already_checked_in', attendeeName, checkedInAt }
//
// Output (invalid):
//   { success: false, status: 'invalid', errorMessage }
// ─────────────────────────────────────────────────────────────────────────────
exports.validateCheckIn = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const { qrPayload, eventId, hostUid } = request.data;

  if (!qrPayload || !eventId) {
    throw new HttpsError("invalid-argument", "qrPayload and eventId are required.");
  }

  // ── Parse QR payload ──────────────────────────────────────────────────────
  const PREFIX = "theydi:checkin:";
  if (!qrPayload.startsWith(PREFIX)) {
    return {
      success      : false,
      status       : "invalid",
      errorMessage : "This QR code is not valid for this event.",
    };
  }
  const token = qrPayload.slice(PREFIX.length).trim();
  if (!token || token.length < 10) {
    return {
      success      : false,
      status       : "invalid",
      errorMessage : "This QR code is not valid for this event.",
    };
  }

  // ── Verify host owns the event ────────────────────────────────────────────
  const eventDoc = await db.collection("events").doc(eventId).get();
  if (!eventDoc.exists) {
    return {
      success      : false,
      status       : "invalid",
      errorMessage : "Event not found.",
    };
  }
  const event = eventDoc.data();
  if (event.creatorUid !== uid) {
    throw new HttpsError("permission-denied", "You are not the host of this event.");
  }

  // ── Find booking by token ─────────────────────────────────────────────────
  const bookingSnap = await db
    .collection("bookings")
    .where("checkInToken", "==", token)
    .where("eventId",       "==", eventId)
    .limit(1)
    .get();

  if (bookingSnap.empty) {
    return {
      success      : false,
      status       : "invalid",
      errorMessage : "This QR code is not valid for this event.",
    };
  }

  const bookingDoc  = bookingSnap.docs[0];
  const bookingId   = bookingDoc.id;
  const booking     = bookingDoc.data();

  // ── Validate booking status ───────────────────────────────────────────────
  const validStatuses = ["confirmed"];
  if (!validStatuses.includes(booking.status)) {
    return {
      success      : false,
      status       : "invalid",
      errorMessage : "This QR code is not valid for this event.",
    };
  }

  // ── Check for duplicate scan ──────────────────────────────────────────────
  const checkInRef = db
    .collection("events")
    .doc(eventId)
    .collection("checkIns")
    .doc(bookingId);

  const checkInDoc = await checkInRef.get();

  if (checkInDoc.exists && checkInDoc.data().checkedIn === true) {
    const ts = checkInDoc.data().checkedInAt;
    return {
      success      : false,
      status       : "already_checked_in",
      attendeeName : booking.userName || "Attendee",
      checkedInAt  : ts ? _formatTime(ts) : "Earlier",
    };
  }

  // ── Mark as checked in ────────────────────────────────────────────────────
  const now = admin.firestore.FieldValue.serverTimestamp();

  // Update booking doc
  await bookingDoc.ref.update({
    checkedIn  : true,
    checkedInAt: now,
    checkedInBy: uid,
  });

  // Upsert checkIns sub-collection doc
  await checkInRef.set({
    eventId,
    bookingId,
    attendeeUserId : booking.userId,
    checkInToken   : token,
    checkedIn      : true,
    checkedInAt    : now,
    checkedInBy    : uid,
    createdAt      : checkInDoc.exists
                       ? checkInDoc.data().createdAt
                       : now,
  }, { merge: true });

  return {
    success      : true,
    status       : "checked_in",
    attendeeName : booking.userName  || "Attendee",
    eventTitle   : event.title       || "",
    checkedInAt  : _formatTime(new Date()),  // approximate — server Timestamp resolves async
  };
});