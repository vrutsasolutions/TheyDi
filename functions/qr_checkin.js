// ─────────────────────────────────────────────────────────────────────────────
// QR Check-in Cloud Functions
//
// Exports:
//   generateCheckInToken   — paid event: called by attendee after booking confirmed
//   generateFreeEventToken — free event: called by attendee in attendeeUids
//   validateCheckIn        — called by host when scanning attendee QR
//
// Both token generators run on admin SDK only — clients cannot write tokens
// directly to Firestore.
//
// Firestore paths used:
//
//   PAID EVENTS:
//   bookings/{bookingId}                      — existing collection
//     .checkInToken      (string, written here)
//     .checkedIn         (bool,   written on scan)
//     .checkedInAt       (Timestamp)
//     .checkedInBy       (string, host uid)
//
//   events/{eventId}/checkIns/{bookingId}     — sub-collection (paid)
//     eventId, bookingId, attendeeUserId,
//     checkInToken, checkedIn, checkedInAt,
//     checkedInBy, createdAt
//
//   FREE EVENTS:
//   events/{eventId}/attendeeTokens/{userId}  — sub-collection (free)
//     userId, checkInToken, checkedIn,
//     checkedInAt, checkedInBy, createdAt
//
//   events/{eventId}/checkIns/{userId}        — same checkIns collection for
//                                               uniformity when scanned
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
// HELPER — generate a unique, human-readable booking reference code
//          Format: TDI-XXXXXX  (6 alphanumeric chars, no ambiguous I/O/1/0)
// ─────────────────────────────────────────────────────────────────────────────
function _generateBookingRef() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 30 chars, no I/O/1/0
  const bytes = crypto.randomBytes(6);
  let ref = "TDI-";
  for (let i = 0; i < 6; i++) {
    ref += chars.charAt(bytes[i] % chars.length);
  }
  return ref;
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — send check-in notification to the attendee
//
// Writes a doc to users/{attendeeUid}/notifications/ which triggers the
// existing sendPushOnNotification Cloud Function (Firestore onCreate trigger).
// ─────────────────────────────────────────────────────────────────────────────
async function _notifyAttendeeCheckedIn(attendeeUid, eventId, eventTitle) {
  try {
    await db.collection("users").doc(attendeeUid)
      .collection("notifications").add({
        type      : "check_in",
        title     : "You're checked in! 🎉",
        body      : `Your QR code was scanned for "${eventTitle}". Enjoy the event!`,
        eventId   : eventId,
        fromUid   : "",
        circleId  : "",
        chatId    : "",
        imageUrl  : "",
        read      : false,
        createdAt : admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (err) {
    // Non-critical — don't let notification failure break check-in
    console.error(`[CheckIn] Failed to notify attendee ${attendeeUid}:`, err);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. generateCheckInToken  (PAID EVENTS)
//
// Called by: AttendeeQrScreen (Flutter) for paid event bookings.
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
    // Migration: if token exists but bookingRef doesn't, generate one now
    let existingRef = booking.bookingRef;
    if (!existingRef) {
      existingRef = _generateBookingRef();
      await bookingRef.update({ bookingRef: existingRef });
      // Also update checkIns doc if it exists
      const existingCheckIn = db
        .collection("events").doc(eventId)
        .collection("checkIns").doc(bookingId);
      const ciDoc = await existingCheckIn.get();
      if (ciDoc.exists) {
        await existingCheckIn.update({ bookingRef: existingRef });
      }
    }
    return { checkInToken: booking.checkInToken, bookingRef: existingRef };
  }

  // Generate new token + booking reference
  const token      = _randomToken();
  const bkRef      = _generateBookingRef();
  const now        = admin.firestore.FieldValue.serverTimestamp();

  // Write token + ref to booking doc
  await bookingRef.update({ checkInToken: token, bookingRef: bkRef });

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
    bookingRef     : bkRef,
    isFreeEvent    : false,
    checkedIn      : false,
    checkedInAt    : null,
    checkedInBy    : null,
    createdAt      : now,
  }, { merge: true });

  return { checkInToken: token, bookingRef: bkRef };
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. generateFreeEventToken  (FREE EVENTS)
//
// Called by: AttendeeQrScreen (Flutter) when the event is free (no booking doc).
// Auth:      Must be signed in. Must be in event.attendeeUids.
//
// Input:  { eventId: string, userId: string }
// Output: { checkInToken: string }
// ─────────────────────────────────────────────────────────────────────────────
exports.generateFreeEventToken = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const { eventId, userId } = request.data;
  if (!eventId || !userId) {
    throw new HttpsError("invalid-argument", "eventId and userId are required.");
  }

  // Caller must match the userId they're requesting for
  if (uid !== userId) {
    throw new HttpsError("permission-denied", "You can only get your own QR code.");
  }

  // Verify the user is actually in attendeeUids on the event
  const eventDoc = await db.collection("events").doc(eventId).get();
  if (!eventDoc.exists) {
    throw new HttpsError("not-found", "Event not found.");
  }

  const event = eventDoc.data();
  const attendeeUids = event.attendeeUids || [];
  if (!attendeeUids.includes(uid)) {
    throw new HttpsError(
      "permission-denied",
      "You are not a confirmed attendee of this event."
    );
  }

  // Check if token already exists in attendeeTokens/{userId}
  const tokenRef = db
    .collection("events")
    .doc(eventId)
    .collection("attendeeTokens")
    .doc(userId);

  const tokenDoc = await tokenRef.get();
  if (tokenDoc.exists && tokenDoc.data().checkInToken) {
    // Migration: if token exists but bookingRef doesn't, generate one now
    let existingRef = tokenDoc.data().bookingRef;
    if (!existingRef) {
      existingRef = _generateBookingRef();
      await tokenRef.update({ bookingRef: existingRef });
      // Also update checkIns doc if it exists
      const existingCheckIn = db
        .collection("events").doc(eventId)
        .collection("checkIns").doc(userId);
      const ciDoc = await existingCheckIn.get();
      if (ciDoc.exists) {
        await existingCheckIn.update({ bookingRef: existingRef });
      }
    }
    return { checkInToken: tokenDoc.data().checkInToken, bookingRef: existingRef };
  }

  // Generate new token + booking reference
  const token = _randomToken();
  const bkRef = _generateBookingRef();
  const now   = admin.firestore.FieldValue.serverTimestamp();

  // Write token + ref to attendeeTokens sub-collection
  await tokenRef.set({
    userId,
    eventId,
    checkInToken : token,
    bookingRef   : bkRef,
    isFreeEvent  : true,
    checkedIn    : false,
    checkedInAt  : null,
    checkedInBy  : null,
    createdAt    : now,
  });

  // Also create the checkIns entry (using userId as doc id for free events)
  const checkInRef = db
    .collection("events")
    .doc(eventId)
    .collection("checkIns")
    .doc(userId);  // userId as doc id (no bookingId for free events)

  await checkInRef.set({
    eventId,
    bookingId      : null,    // no booking for free events
    attendeeUserId : uid,
    checkInToken   : token,
    bookingRef     : bkRef,
    isFreeEvent    : true,
    checkedIn      : false,
    checkedInAt    : null,
    checkedInBy    : null,
    createdAt      : now,
  }, { merge: true });

  return { checkInToken: token, bookingRef: bkRef };
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. validateCheckIn
//
// Called by: HostScannerScreen (Flutter) after host scans a QR.
// Auth:      Must be signed in as the event host.
//
// Handles both paid and free event tokens.
//
// Input:  { qrPayload: string, eventId: string, hostUid: string }
//         qrPayload format: "theydi:checkin:<token>" or "theydi:ref:<bookingRef>"
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
  const TOKEN_PREFIX = "theydi:checkin:";
  const REF_PREFIX   = "theydi:ref:";

  let token     = null;   // set when payload is a QR token
  let refCode   = null;   // set when payload is a booking reference

  if (qrPayload.startsWith(TOKEN_PREFIX)) {
    token = qrPayload.slice(TOKEN_PREFIX.length).trim();
    if (!token || token.length < 10) {
      return {
        success      : false,
        status       : "invalid",
        errorMessage : "This QR code is not valid for this event.",
      };
    }
  } else if (qrPayload.startsWith(REF_PREFIX)) {
    refCode = qrPayload.slice(REF_PREFIX.length).trim().toUpperCase();
    if (!refCode || refCode.length < 4) {
      return {
        success      : false,
        status       : "invalid",
        errorMessage : "Invalid booking reference code.",
      };
    }
  } else {
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

  // ── Try paid event path first ────────────────────────────────────────────
  // Search by checkInToken or bookingRef depending on payload type
  const bookingQuery = token
    ? db.collection("bookings")
        .where("checkInToken", "==", token)
        .where("eventId",       "==", eventId)
        .limit(1)
    : db.collection("bookings")
        .where("bookingRef",   "==", refCode)
        .where("eventId",      "==", eventId)
        .limit(1);

  const bookingSnap = await bookingQuery.get();

  if (!bookingSnap.empty) {
    // ── PAID EVENT PATH ──────────────────────────────────────────────────────
    const bookingDoc  = bookingSnap.docs[0];
    const bookingId   = bookingDoc.id;
    const booking     = bookingDoc.data();

    // Validate booking status
    if (booking.status !== "confirmed") {
      return {
        success      : false,
        status       : "invalid",
        errorMessage : "This QR code is not valid for this event.",
      };
    }

    // Check for duplicate scan
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

    // Mark as checked in
    const now = admin.firestore.FieldValue.serverTimestamp();

    await bookingDoc.ref.update({
      checkedIn  : true,
      checkedInAt: now,
      checkedInBy: uid,
    });

    await checkInRef.set({
      eventId,
      bookingId,
      attendeeUserId : booking.userId,
      checkInToken   : token,
      isFreeEvent    : false,
      checkedIn      : true,
      checkedInAt    : now,
      checkedInBy    : uid,
      createdAt      : checkInDoc.exists
                         ? checkInDoc.data().createdAt
                         : now,
    }, { merge: true });

    // Notify attendee that they've been checked in
    await _notifyAttendeeCheckedIn(booking.userId, eventId, event.title || "");

    return {
      success      : true,
      status       : "checked_in",
      attendeeName : booking.userName  || "Attendee",
      eventTitle   : event.title       || "",
      checkedInAt  : _formatTime(new Date()),
    };
  }

  // ── FREE EVENT PATH: search attendeeTokens by token or bookingRef ────────
  const freeTokenQuery = token
    ? db.collection("events").doc(eventId)
        .collection("attendeeTokens")
        .where("checkInToken", "==", token)
        .limit(1)
    : db.collection("events").doc(eventId)
        .collection("attendeeTokens")
        .where("bookingRef", "==", refCode)
        .limit(1);

  const freeTokenSnap = await freeTokenQuery.get();

  if (!freeTokenSnap.empty) {
    const tokenDoc    = freeTokenSnap.docs[0];
    const tokenData   = tokenDoc.data();
    const attendeeUid = tokenData.userId;

    // Check for duplicate scan (using userId as checkIns doc id for free events)
    const checkInRef = db
      .collection("events")
      .doc(eventId)
      .collection("checkIns")
      .doc(attendeeUid);

    const checkInDoc = await checkInRef.get();

    if (checkInDoc.exists && checkInDoc.data().checkedIn === true) {
      const ts = checkInDoc.data().checkedInAt;
      // Fetch attendee name for the response
      let attendeeName = "Attendee";
      try {
        const userDoc = await db.collection("users").doc(attendeeUid).get();
        if (userDoc.exists) {
          const ud = userDoc.data();
          attendeeName = ud.displayName || ud.fullName || ud.name || "Attendee";
        }
      } catch (_) {}
      return {
        success      : false,
        status       : "already_checked_in",
        attendeeName,
        checkedInAt  : ts ? _formatTime(ts) : "Earlier",
      };
    }

    // Fetch attendee name
    let attendeeName = "Attendee";
    try {
      const userDoc = await db.collection("users").doc(attendeeUid).get();
      if (userDoc.exists) {
        const ud = userDoc.data();
        attendeeName = ud.displayName || ud.fullName || ud.name || "Attendee";
      }
    } catch (_) {}

    // Mark as checked in
    const now = admin.firestore.FieldValue.serverTimestamp();

    // Update attendeeTokens doc
    await tokenDoc.ref.update({
      checkedIn  : true,
      checkedInAt: now,
      checkedInBy: uid,
    });

    // Upsert checkIns doc (userId as doc id for free events)
    await checkInRef.set({
      eventId,
      bookingId      : null,
      attendeeUserId : attendeeUid,
      checkInToken   : token,
      isFreeEvent    : true,
      checkedIn      : true,
      checkedInAt    : now,
      checkedInBy    : uid,
      createdAt      : checkInDoc.exists
                         ? checkInDoc.data().createdAt
                         : now,
    }, { merge: true });

    // Notify attendee that they've been checked in
    await _notifyAttendeeCheckedIn(attendeeUid, eventId, event.title || "");

    return {
      success      : true,
      status       : "checked_in",
      attendeeName,
      eventTitle   : event.title || "",
      checkedInAt  : _formatTime(new Date()),
    };
  }

  // ── Token / ref not found in bookings or attendeeTokens ────────────────────
  return {
    success      : false,
    status       : "invalid",
    errorMessage : refCode
      ? "Booking reference not found for this event."
      : "This QR code is not valid for this event.",
  };
});