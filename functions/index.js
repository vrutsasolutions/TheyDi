const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const Razorpay = require("razorpay");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();
const REGION = "asia-south1";

function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

const REFERRAL_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const REFERRAL_CODE_LENGTH = 8;
const REFERRAL_CODE_PATTERN = /^[A-Z0-9]{6,12}$/;
const NEW_ACCOUNT_ATTRIBUTION_WINDOW_MS = 24 * 60 * 60 * 1000;

function normalizeReferralCode(code) {
  return String(code || "").trim().toUpperCase();
}

function isValidReferralCodeFormat(code) {
  return REFERRAL_CODE_PATTERN.test(code);
}

function generateReferralCode() {
  let code = "";
  for (let i = 0; i < REFERRAL_CODE_LENGTH; i++) {
    const index = crypto.randomInt(0, REFERRAL_ALPHABET.length);
    code += REFERRAL_ALPHABET[index];
  }
  return code;
}

async function createReferralCodeForUser(uid) {
  const userRef = db.collection("users").doc(uid);

  for (let attempt = 0; attempt < 12; attempt++) {
    const code = generateReferralCode();
    const codeRef = db.collection("referralCodes").doc(code);

    try {
      await db.runTransaction(async (tx) => {
        const [userDoc, codeDoc] = await Promise.all([
          tx.get(userRef),
          tx.get(codeRef),
        ]);

        if (!userDoc.exists) {
          throw new HttpsError("not-found", "User profile not found.");
        }

        const existingCode = userDoc.data().referralCode;
        if (existingCode && isValidReferralCodeFormat(existingCode)) {
          const existingCodeRef = db.collection("referralCodes").doc(existingCode);
          const existingCodeDoc = await tx.get(existingCodeRef);
          if (!existingCodeDoc.exists) {
            tx.set(existingCodeRef, {
              code: existingCode,
              uid,
              createdAt: FieldValue.serverTimestamp(),
            });
          } else if (existingCodeDoc.data().uid !== uid) {
            throw new HttpsError("already-exists", "Referral code is already assigned.");
          }
          return;
        }

        if (codeDoc.exists) {
          throw new Error("code-collision");
        }

        tx.set(codeRef, {
          code,
          uid,
          createdAt: FieldValue.serverTimestamp(),
        });
        tx.set(userRef, {
          referralCode: code,
          referralCodeCreatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      });

      const userDoc = await userRef.get();
      return userDoc.data().referralCode;
    } catch (error) {
      if (error.message === "code-collision") continue;
      throw error;
    }
  }

  throw new HttpsError("resource-exhausted", "Could not generate a unique referral code.");
}

exports.ensureReferralCode = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to get an invite code.");
  }

  const uid = request.auth.uid;
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }

  const existingCode = userDoc.data().referralCode;
  if (existingCode && isValidReferralCodeFormat(existingCode)) {
    const referralCode = await createReferralCodeForUser(uid);
    return { referralCode };
  }

  const referralCode = await createReferralCodeForUser(uid);
  return { referralCode };
});

exports.validateReferralCode = onCall({ region: REGION }, async (request) => {
  const referralCode = normalizeReferralCode(request.data?.referralCode);
  if (!isValidReferralCodeFormat(referralCode)) {
    return { valid: false, error: "This invite link is invalid." };
  }

  const codeDoc = await db.collection("referralCodes").doc(referralCode).get();
  if (!codeDoc.exists) {
    return { valid: false, error: "This invite code does not exist." };
  }

  const referrerUid = codeDoc.data().uid;
  const referrerDoc = await db.collection("users").doc(referrerUid).get();
  if (!referrerDoc.exists) {
    return { valid: false, error: "This invite code is no longer active." };
  }

  const referrer = referrerDoc.data();
  return {
    valid: true,
    referrerUid,
    referrerName: referrer.displayName || referrer.name || "A TheyDi friend",
  };
});

exports.attributeReferral = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to accept an invite.");
  }

  const inviteeUid = request.auth.uid;
  const referralCode = normalizeReferralCode(request.data?.referralCode);
  if (!isValidReferralCodeFormat(referralCode)) {
    throw new HttpsError("invalid-argument", "Invalid referral code.");
  }

  const inviteeRef = db.collection("users").doc(inviteeUid);
  const codeRef = db.collection("referralCodes").doc(referralCode);
  const authUser = await admin.auth().getUser(inviteeUid);
  const createdAtMs = new Date(authUser.metadata.creationTime).getTime();
  if (!createdAtMs || Date.now() - createdAtMs > NEW_ACCOUNT_ATTRIBUTION_WINDOW_MS) {
    return { success: false, notNewSignup: true };
  }

  return db.runTransaction(async (tx) => {
    const [inviteeDoc, codeDoc] = await Promise.all([
      tx.get(inviteeRef),
      tx.get(codeRef),
    ]);

    if (!inviteeDoc.exists) {
      throw new HttpsError("not-found", "Invitee profile not found.");
    }
    if (!codeDoc.exists) {
      throw new HttpsError("not-found", "Referral code not found.");
    }

    const invitee = inviteeDoc.data();
    if (invitee.referredBy || invitee.referredByUid || invitee.referralAttributedAt) {
      return { success: false, alreadyAttributed: true };
    }

    const referrerUid = codeDoc.data().uid;
    if (!referrerUid || referrerUid === inviteeUid) {
      throw new HttpsError("failed-precondition", "Self-referrals are not allowed.");
    }

    const referralRef = db.collection("referrals").doc(inviteeUid);
    const referralDoc = await tx.get(referralRef);
    if (referralDoc.exists) {
      return { success: false, alreadyAttributed: true };
    }

    tx.set(referralRef, {
      referralCode,
      referrerUid,
      referredUid: inviteeUid,
      inviteeUid,
      status: "attributed",
      createdAt: FieldValue.serverTimestamp(),
      attributedAt: FieldValue.serverTimestamp(),
    });
    tx.set(inviteeRef, {
      referredBy: referrerUid,
      referredByUid: referrerUid,
      referredByCode: referralCode,
      referralAttributedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.set(db.collection("users").doc(referrerUid), {
      referralCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return { success: true, referrerUid };
  });
});

exports.ensureReferralCodeOnUserCreate = onDocumentCreated(
  { document: "users/{uid}", region: REGION },
  async (event) => {
    await createReferralCodeForUser(event.params.uid);
  },
);

exports.notifyAllUsersAboutEvent_TEST = onDocumentCreated(
  { document: "events/{eventId}", region: REGION },
  async (event) => {
    const eventData = event.data?.data();
    if (!eventData) {
      logger.log("Event data not found");
      return;
    }
    const eventId = event.params.eventId;

    const usersSnapshot = await db.collection("users").get();
    const batch = db.batch();
    let notifiedCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const notificationRef = db
        .collection("users")
        .doc(userDoc.id)
        .collection("notifications")
        .doc();

      batch.set(notificationRef, {
        type: "nearby_event",
        title: "New event created",
        body: eventData.title
          ? `${eventData.title} was just created — check it out!`
          : "A new event was just created — check it out!",
        message: eventData.title
          ? `${eventData.title} was just created — check it out!`
          : "A new event was just created — check it out!",
        eventId: eventId,
        imageUrl: eventData.imageUrl || null,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
      notifiedCount++;
    }

    await batch.commit();
    logger.log(`[TEST] Created event notifications for ${notifiedCount} users for event ${eventId}`);
  },
);



// exports.notifyNearbyUsersAboutEvent = onDocumentCreated(
//   { document: "events/{eventId}", region: REGION },
//   async (event) => {
//     const eventData = event.data?.data();
//     if (!eventData) {
//       logger.log("Event data not found");
//       return;
//     }
//     const eventId = event.params.eventId;
//     const latitude = eventData.latitude;
//     const longitude = eventData.longitude;
//     if (latitude == null || longitude == null) {
//       logger.log(`Event ${eventId} has no location`);
//       return;
//     }

//     const usersSnapshot = await db.collection("users").get();
//     const batch = db.batch();
//     let nearbyUsers = 0;

//     for (const userDoc of usersSnapshot.docs) {
//       const user = userDoc.data();
//       const userLatitude = user.latitude;
//       const userLongitude = user.longitude;
//       if (userLatitude == null || userLongitude == null) continue;

//       const distance = calculateDistance(
//         Number(latitude), Number(longitude), Number(userLatitude), Number(userLongitude),
//       );

//       if (distance <= 20) {
//         nearbyUsers++;
//         const notificationRef = db.collection("users").doc(userDoc.id).collection("notifications").doc();
//         batch.set(notificationRef, {
//           type: "nearby_event",
//           title: "New event near you",
//           body: eventData.title ? `${eventData.title} is happening near you` : "A new event is happening near you",
//           message: eventData.title ? `${eventData.title} is happening near you` : "A new event is happening near you",
//           eventId: eventId,
//           imageUrl: eventData.imageUrl || null,
//           isRead: false,
//           createdAt: FieldValue.serverTimestamp(),
//         });
//       }
//     }

//     await batch.commit();
//     logger.log(`Created nearby event notifications for ${nearbyUsers} users for event ${eventId}`);
//   },
// );

function getBaseEmailHtml(title, bodyContent) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F3F4F6; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; background-color: #FFFFFF; margin: 40px auto; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05); border: 1px solid #E5E7EB;">
    <tr>
      <td align="center" style="padding: 30px 0 20px 0; border-bottom: 1px solid #E5E7EB;">
        <h1 style="color: #10B981; font-size: 28px; font-weight: 700; margin: 0; letter-spacing: 1px;">TheyDi</h1>
      </td>
    </tr>
    <tr>
      <td style="padding: 40px 40px 20px 40px;">
        ${bodyContent}
      </td>
    </tr>
    <tr>
      <td align="center" style="padding: 24px 40px; background-color: #F9FAFB; border-top: 1px solid #E5E7EB;">
        <p style="color: #9CA3AF; font-size: 12px; line-height: 18px; margin: 0;">
          © 2026 TheyDi App. All rights reserved.
        </p>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function getRazorpay() {
  const keyId = (process.env.RAZORPAY_KEY_ID || "").trim();
  const keySecret = (process.env.RAZORPAY_SECRET_KEY || "").trim();
  if (!keyId || !keySecret) {
    logger.warn("Razorpay keys are missing from environment variables.");
    return null;
  }
  return new Razorpay({ key_id: keyId, key_secret: keySecret });
}

function getTransporter() {
  const user = process.env.GMAIL_USER;
  const pass = process.env.GMAIL_APP_PASSWORD;
  if (!user || !pass) {
    logger.warn("Gmail credentials are missing from environment variables.");
    return null;
  }
  return nodemailer.createTransport({ service: "gmail", auth: { user, pass } });
}

exports.createOrder = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in to create an order.");
  }

  const razorpay = getRazorpay();
  if (!razorpay) {
    throw new HttpsError("internal", "Razorpay is not configured on the server.");
  }

  const { amount, currency, receipt, notes } = request.data;

  if (!amount || typeof amount !== "number" || !Number.isInteger(amount)) {
    throw new HttpsError("invalid-argument", "A valid integer amount (in paise) is required.");
  }
  if (amount < 100) {
    throw new HttpsError("invalid-argument", "Amount must be at least ₹1 (100 paise).");
  }

  try {
    const options = {
      amount: amount,
      currency: currency || "INR",
      receipt: receipt || `rcptid_${Date.now()}`,
      notes: notes || {},
    };
    const order = await razorpay.orders.create(options);
    logger.info("Order created successfully", { orderId: order.id });
    return { orderId: order.id, amount: order.amount, currency: order.currency };
  } catch (error) {
    logger.error("Error creating Razorpay order", {
      message: error.message,
      statusCode: error.statusCode,
      description: error.error?.description || error.description,
    });
    const detailMsg = error.error?.description || error.message || "Unknown Razorpay error";
    throw new HttpsError("internal", `Failed to create Razorpay order: ${detailMsg}`);
  }
});

exports.verifyPayment = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in to verify payment.");
  }

  const {
    razorpay_payment_id, razorpay_order_id, razorpay_signature,
    eventId, eventTitle, hostUid, amount, platformFee, totalAmount,
    paymentMethod, fromApproval,
  } = request.data;

  if (!razorpay_payment_id || !razorpay_order_id || !razorpay_signature) {
    throw new HttpsError("invalid-argument", "Missing payment verification parameters.");
  }

  const uid = request.auth.uid;
  let userName = request.auth.token.name || request.auth.token.email?.split("@")[0] || "User";

  const keySecret = (process.env.RAZORPAY_SECRET_KEY || "").trim();
  if (!keySecret) {
    throw new HttpsError("internal", "Razorpay secret key is not configured.");
  }

  const body = razorpay_order_id + "|" + razorpay_payment_id;
  const expectedSignature = crypto.createHmac("sha256", keySecret).update(body.toString()).digest("hex");

  if (expectedSignature !== razorpay_signature) {
    logger.error("Payment signature verification failed");
    throw new HttpsError("permission-denied", "Payment signature is invalid.");
  }

  try {
    const existingPaymentRef = await db.collection("events").doc(eventId)
      .collection("attendeePayments").doc(uid).get();

    if (existingPaymentRef.exists && existingPaymentRef.data().status === "paid") {
      logger.info("Payment already processed by webhook. Skipping duplicate write.");
      return { success: true, message: "Payment already verified by webhook." };
    }

    const userDoc = await db.collection("users").doc(uid).get();
    if (userDoc.exists) {
      const data = userDoc.data();
      userName = data.displayName || data.fullName || data.name || userName;
    }

    const bookingData = {
      eventId, eventTitle, userId: uid, userName, hostUid,
      amount, platformFee, totalAmount,
      status: "confirmed",
      paymentMethod: paymentMethod || "Unknown",
      transactionId: razorpay_payment_id,
      createdAt: FieldValue.serverTimestamp(),
      confirmedAt: FieldValue.serverTimestamp(),
    };

    const batch = db.batch();

    const newBookingRef = db.collection("bookings").doc();
    batch.set(newBookingRef, bookingData);

    const eventRef = db.collection("events").doc(eventId);
    const eventUpdates = { attendeeUids: FieldValue.arrayUnion(uid) };
    if (fromApproval) {
      eventUpdates.approvedPendingPaymentUids = FieldValue.arrayRemove(uid);
    }
    batch.update(eventRef, eventUpdates);

    const paymentRef = eventRef.collection("attendeePayments").doc(uid);
    batch.set(paymentRef, {
      status: "paid", userName, transactionId: razorpay_payment_id,
      paymentMethod: paymentMethod || "Unknown", amount: totalAmount,
      paidAt: FieldValue.serverTimestamp(), eventId,
    }, { merge: true });

    const userRef = db.collection("users").doc(uid);
    batch.set(userRef, { eventsAttended: FieldValue.increment(1) }, { merge: true });

    const globalPaymentRef = db.collection("payment").doc(razorpay_payment_id);
    batch.set(globalPaymentRef, {
      amount: amount || totalAmount || 0,
      createdAt: FieldValue.serverTimestamp(),
      currency: "INR", eventId: eventId, orderId: razorpay_order_id,
      paymentId: razorpay_payment_id, paymentMethod: paymentMethod || "Unknown",
      status: "Success", uid: uid, username: userName, verified: true,
    });

    await batch.commit();
    return { success: true, message: "Payment verified and booking confirmed." };
  } catch (error) {
    logger.error("Failed to process booking after payment validation", error);
    throw new HttpsError("internal", "Payment was verified but failed to write booking to database.");
  }
});

exports.razorpayWebhook = onRequest(
  { region: REGION, secrets: ["RAZORPAY_WEBHOOK_SECRET"] },
  async (req, res) => {
    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;

    if (webhookSecret) {
      const signature = req.headers["x-razorpay-signature"];
      if (!signature) return res.status(400).send("No signature found");
      const expectedSignature = crypto.createHmac("sha256", webhookSecret).update(req.rawBody).digest("hex");
      if (expectedSignature !== signature) {
        logger.error("Webhook signature verification failed");
        return res.status(400).send("Invalid signature");
      }
    } else {
      logger.warn("RAZORPAY_WEBHOOK_SECRET not set. Proceeding without signature verification (NOT RECOMMENDED for production).");
    }

    try {
      const event = req.body;

      if (event.event === "order.paid") {
        const order = event.payload.order.entity;
        const payment = event.payload.payment.entity;
        const { notes } = order;

        if (!notes || !notes.eventId || !notes.userId) {
          logger.info("Ignored webhook: missing notes");
          return res.status(200).send("Ignored, missing notes");
        }

        const existingPaymentRef = await db.collection("events").doc(notes.eventId)
          .collection("attendeePayments").doc(notes.userId).get();

        if (existingPaymentRef.exists && existingPaymentRef.data().status === "paid") {
          logger.info("Payment already processed by client");
          return res.status(200).send("Already processed");
        }

        logger.info("Processing webhook for order.paid", { orderId: order.id, userId: notes.userId });

        let resolvedUserName = "User";
        try {
          const userDoc = await db.collection("users").doc(notes.userId).get();
          if (userDoc.exists) {
            const data = userDoc.data();
            resolvedUserName = data.displayName || data.fullName || data.name || "User";
          }
        } catch (_) {}

        const bookingData = {
          eventId: notes.eventId,
          eventTitle: notes.eventTitle || "Unknown Event",
          userId: notes.userId, userName: resolvedUserName, hostUid: notes.hostUid,
          amount: order.amount / 100,
          platformFee: parseFloat(notes.platformFee || "0"),
          totalAmount: parseFloat(notes.totalAmount || "0"),
          status: "confirmed",
          paymentMethod: payment.method || "Unknown",
          transactionId: payment.id,
          createdAt: FieldValue.serverTimestamp(),
          confirmedAt: FieldValue.serverTimestamp(),
        };

        const batch = db.batch();

        const newBookingRef = db.collection("bookings").doc();
        batch.set(newBookingRef, bookingData);

        const eventRef = db.collection("events").doc(notes.eventId);
        const eventUpdates = { attendeeUids: FieldValue.arrayUnion(notes.userId) };
        if (notes.fromApproval === "true") {
          eventUpdates.approvedPendingPaymentUids = FieldValue.arrayRemove(notes.userId);
        }
        batch.update(eventRef, eventUpdates);

        const paymentRef = eventRef.collection("attendeePayments").doc(notes.userId);
        batch.set(paymentRef, {
          status: "paid", userName: resolvedUserName, transactionId: payment.id,
          paymentMethod: payment.method || "Unknown", amount: bookingData.totalAmount,
          paidAt: FieldValue.serverTimestamp(), eventId: notes.eventId,
        }, { merge: true });

        const userRef = db.collection("users").doc(notes.userId);
        batch.update(userRef, { eventsAttended: FieldValue.increment(1) });

        const globalPaymentRef = db.collection("payment").doc(payment.id);
        batch.set(globalPaymentRef, {
          amount: bookingData.totalAmount,
          createdAt: FieldValue.serverTimestamp(),
          currency: "INR", eventId: notes.eventId, orderId: order.id,
          paymentId: payment.id, paymentMethod: payment.method || "Unknown",
          status: "Success", uid: notes.userId, username: resolvedUserName, verified: true,
        });

        await batch.commit();
        logger.info("Webhook processed payment successfully", { orderId: order.id });
      }

      return res.status(200).send("OK");
    } catch (error) {
      logger.error("Error processing webhook", error);
      return res.status(500).send("Internal Server Error");
    }
  }
);

function encryptField(plainText) {
  if (!plainText) return null;
  const key = Buffer.from((process.env.PAYOUT_ENCRYPTION_KEY || "").trim(), "hex");
  if (key.length !== 32) {
    throw new Error("PAYOUT_ENCRYPTION_KEY is not configured or not 32 bytes.");
  }
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([cipher.update(String(plainText), "utf8"), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return Buffer.concat([iv, authTag, encrypted]).toString("base64");
}

function decryptField(encoded) {
  if (!encoded) return null;
  const key = Buffer.from((process.env.PAYOUT_ENCRYPTION_KEY || "").trim(), "hex");
  const data = Buffer.from(encoded, "base64");
  const iv = data.subarray(0, 12);
  const authTag = data.subarray(12, 28);
  const encrypted = data.subarray(28);
  const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(authTag);
  const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
  return decrypted.toString("utf8");
}

exports.savePayoutDetails = onCall(
  { region: REGION, secrets: ["PAYOUT_ENCRYPTION_KEY"] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in.");

    const uid = request.auth.uid;
    const { payoutMethod, upiId, name, ifsc, accountNumber, bankName } = request.data;
    const isUpi = payoutMethod === "upi";

    if (isUpi) {
      if (!upiId) throw new HttpsError("invalid-argument", "Missing UPI ID.");
    } else if (payoutMethod === "bank") {
      if (!name || !ifsc || !accountNumber) {
        throw new HttpsError("invalid-argument", "Missing bank details.");
      }
    } else {
      throw new HttpsError("invalid-argument", "payoutMethod must be 'upi' or 'bank'.");
    }

    let payoutDoc;
    try {
      payoutDoc = {
        payoutMethod,
        name: name || null,
        bankName: !isUpi ? (bankName || null) : null,
        upiId: isUpi ? encryptField(upiId) : null,
        accountNumber: !isUpi ? encryptField(accountNumber) : null,
        ifsc: !isUpi ? encryptField(ifsc) : null,
        updatedAt: FieldValue.serverTimestamp(),
      };
    } catch (encErr) {
      logger.error("[Payout] Encryption failed:", encErr);
      throw new HttpsError("internal", "Failed to secure payout details.");
    }

    try {
      await db.collection("users").doc(uid)
        .collection("private").doc("payoutDetails")
        .set(payoutDoc, { merge: true });

      await db.collection("users").doc(uid).set({
        payoutSetupCompleted: true,
        payoutMode: payoutMethod,
      }, { merge: true });

      logger.info(`[Payout] Saved payout details for UID: ${uid} (method: ${payoutMethod})`);
      return { success: true };
    } catch (e) {
      logger.error("[Payout] Failed to save payout details:", e);
      throw new HttpsError("internal", "Failed to save payout details.");
    }
  }
);

exports.saveContactDetails = onCall(
  { region: REGION, secrets: ["PAYOUT_ENCRYPTION_KEY"] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in.");

    const uid = request.auth.uid;
    const { mobile } = request.data;
    if (!mobile || !mobile.trim()) {
      throw new HttpsError("invalid-argument", "Missing mobile number.");
    }

    let encryptedMobile;
    try {
      encryptedMobile = encryptField(mobile.trim());
    } catch (encErr) {
      logger.error("[Contact] Encryption failed:", encErr);
      throw new HttpsError("internal", "Failed to secure contact details.");
    }

    try {
      await db.collection("users").doc(uid)
        .collection("private").doc("contactDetails")
        .set({ mobile: encryptedMobile, updatedAt: FieldValue.serverTimestamp() }, { merge: true });

      logger.info(`[Contact] Saved mobile number for UID: ${uid}`);
      return { success: true };
    } catch (e) {
      logger.error("[Contact] Failed to save contact details:", e);
      throw new HttpsError("internal", "Failed to save contact details.");
    }
  }
);

exports.getMyContactDetails = onCall(
  { region: REGION, secrets: ["PAYOUT_ENCRYPTION_KEY"] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in.");
    const uid = request.auth.uid;

    const doc = await db.collection("users").doc(uid)
      .collection("private").doc("contactDetails").get();
    if (!doc.exists) return { exists: false, mobile: null };

    try {
      return { exists: true, mobile: decryptField(doc.data().mobile) };
    } catch (decErr) {
      logger.error("[Contact] Decryption failed:", decErr);
      throw new HttpsError("internal", "Failed to read contact details.");
    }
  }
);

exports.getContactDetailsForAdmin = onCall(
  { region: REGION, secrets: ["PAYOUT_ENCRYPTION_KEY"] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in.");

    const callerDoc = await db.collection("users").doc(request.auth.uid).get();
    if (!callerDoc.exists || callerDoc.data().isAdmin !== true) {
      throw new HttpsError("permission-denied", "Admin access required.");
    }

    const { targetUid } = request.data;
    if (!targetUid) throw new HttpsError("invalid-argument", "Missing targetUid.");

    const doc = await db.collection("users").doc(targetUid)
      .collection("private").doc("contactDetails").get();
    if (!doc.exists) {
      throw new HttpsError("not-found", "No contact details on file for this user.");
    }

    try {
      return { mobile: decryptField(doc.data().mobile) };
    } catch (decErr) {
      logger.error("[Contact] Admin decryption failed:", decErr);
      throw new HttpsError("internal", "Failed to read contact details.");
    }
  }
);

exports.getPayoutDetailsForAdmin = onCall(
  { region: REGION, secrets: ["PAYOUT_ENCRYPTION_KEY"] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in.");

    const callerDoc = await db.collection("users").doc(request.auth.uid).get();
    if (!callerDoc.exists || callerDoc.data().isAdmin !== true) {
      throw new HttpsError("permission-denied", "Admin access required.");
    }

    const { hostUid } = request.data;
    if (!hostUid) throw new HttpsError("invalid-argument", "Missing hostUid.");

    const payoutDoc = await db.collection("users").doc(hostUid)
      .collection("private").doc("payoutDetails").get();

    if (!payoutDoc.exists) {
      throw new HttpsError("not-found", "No payout details on file for this host.");
    }

    const data = payoutDoc.data();
    try {
      return {
        payoutMethod: data.payoutMethod,
        name: data.name,
        bankName: data.bankName || null,
        upiId: decryptField(data.upiId),
        accountNumber: decryptField(data.accountNumber),
        ifsc: decryptField(data.ifsc),
      };
    } catch (decErr) {
      logger.error("[Payout] Decryption failed:", decErr);
      throw new HttpsError("internal", "Failed to read payout details.");
    }
  }
);

exports.getMyPayoutDetailsMasked = onCall(
  { region: REGION, secrets: ["PAYOUT_ENCRYPTION_KEY"] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in.");
    const uid = request.auth.uid;

    const doc = await db.collection("users").doc(uid)
      .collection("private").doc("payoutDetails").get();
    if (!doc.exists) return { exists: false };

    const data = doc.data();
    const mask = (encrypted) => {
      if (!encrypted) return null;
      try {
        const full = decryptField(encrypted);
        return full.length > 4 ? "•".repeat(full.length - 4) + full.slice(-4) : full;
      } catch (e) {
        logger.error("[Payout] Mask decrypt failed:", e);
        return null;
      }
    };

    return {
      exists: true,
      payoutMethod: data.payoutMethod,
      name: data.name,
      bankName: data.bankName || null,
      accountNumberMasked: mask(data.accountNumber),
      ifscMasked: mask(data.ifsc),
      upiIdMasked: mask(data.upiId),
    };
  }
);

exports.markPayoutCompleted = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in.");

  const callerDoc = await db.collection("users").doc(request.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data().isAdmin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const { payoutId, paymentReference } = request.data;
  if (!payoutId || !paymentReference || !paymentReference.trim()) {
    throw new HttpsError("invalid-argument", "Missing payoutId or paymentReference.");
  }

  const payoutRef = db.collection("payouts").doc(payoutId);
  const payoutDoc = await payoutRef.get();
  if (!payoutDoc.exists) throw new HttpsError("not-found", "Payout not found.");
  if (payoutDoc.data().status === "completed") {
    throw new HttpsError("failed-precondition", "Payout already marked completed.");
  }

  const bookingIds = payoutDoc.data().bookingIds || [];

  const batch = db.batch();
  batch.update(payoutRef, {
    status: "completed",
    completedAt: FieldValue.serverTimestamp(),
    completedBy: request.auth.uid,
    paymentReference: paymentReference.trim(),
  });
  for (const bookingId of bookingIds) {
    batch.update(db.collection("bookings").doc(bookingId), {
      payoutStatus: "completed",
    });
  }
  await batch.commit();

  logger.info(`[Payout] Marked payout ${payoutId} completed by admin ${request.auth.uid}`);
  return { success: true };
});

/**
 * processEventCompletion (internal helper)
 * Creates a payouts/{id} doc summarizing what a host is owed once their
 * event ends, and tags each covered booking with payoutId + payoutStatus.
 * Does NOT transfer money — no payout provider is wired up. A human (admin)
 * is responsible for actually transferring funds and calling
 * markPayoutCompleted afterward.
 */
async function processEventCompletion(eventId) {
  if (!eventId) {
    throw new HttpsError("invalid-argument", "Event ID required.");
  }

  logger.info(`[EventCompletion] Processing completion for event: ${eventId}`);

  const eventDoc = await db.collection("events").doc(eventId).get();
  if (!eventDoc.exists) {
    throw new HttpsError("not-found", "Event not found.");
  }

  const eventData = eventDoc.data();

  // =========================================================
  // 1. NEVER process a cancelled event
  // =========================================================
  if (eventData.status === "cancelled") {
    logger.info(`[EventCompletion] Event ${eventId} is cancelled. Skipping completion and payout.`);
    return { success: true, skipped: true, reason: "cancelled", bookingsProcessed: 0, totalPending: 0 };
  }

  // =========================================================
  // 2. Idempotency guard
  // =========================================================
  if (eventData.payoutProcessed === true) {
    logger.info(`[EventCompletion] Event ${eventId} already processed, skipping.`);
    return { success: true, skipped: true, reason: "already_processed", bookingsProcessed: 0, totalPending: 0 };
  }

  const hostUid = eventData.creatorUid;
  const hostDoc = await db.collection("users").doc(hostUid).get();
  const hostData = hostDoc.data() || {};

  // =========================================================
  // 3. Get confirmed bookings
  //    NOTE: We deliberately do NOT gate this on eventData.isFree or
  //    eventData.price. Those fields describe how the event was *listed*,
  //    not what actually changed hands. The only source of truth for
  //    whether a host is owed money is the bookings that were actually
  //    paid for via Razorpay (bData.totalAmount / bData.amount below).
  //    This also protects against isFree/price ever disagreeing with
  //    each other due to a bug elsewhere in event creation.
  // =========================================================
  const allBookingsSnap = await db.collection("bookings").where("eventId", "==", eventId).get();
  const confirmedBookings = allBookingsSnap.docs.filter((d) => d.data().status === "confirmed");
  const unpaidBookings = confirmedBookings.filter((d) => !["completed"].includes(d.data().payoutStatus));
  const attendeeUids = eventData.attendeeUids || [];

  let totalPending = 0;
  let bookingsProcessed = 0;
  const eligibleBookingIds = [];

  for (const doc of unpaidBookings) {
    const bData = doc.data();

    if (!attendeeUids.includes(bData.userId)) {
      logger.info(`[EventCompletion] Skipping booking ${doc.id} — user no longer in attendee list.`);
      continue;
    }

    const baseAmount = bData.amount !== undefined
      ? Number(bData.amount)
      : Number(bData.totalAmount || 0) - Number(bData.platformFee || 0);

    const payoutAmount = Number(baseAmount.toFixed(2));

    if (payoutAmount > 0) {
      totalPending += payoutAmount;
      bookingsProcessed++;
      eligibleBookingIds.push(doc.id);
    }
  }

  totalPending = Number(totalPending.toFixed(2));

  const hasBookings = confirmedBookings.length > 0;
  const hasPayout = totalPending > 0 && eligibleBookingIds.length > 0;

  logger.info(
    `[EventCompletion] Event ${eventId}: hasBookings=${hasBookings}, ` +
    `eligibleBookings=${eligibleBookingIds.length}, totalPending=${totalPending}, hasPayout=${hasPayout}`
  );

  // =========================================================
  // 4. Create payout ONLY when actual money is owed
  // =========================================================
  let payoutId = null;

  if (hasPayout) {
    const payoutRef = await db.collection("payouts").add({
      hostUid,
      eventId,
      eventTitle: eventData.title || "Unknown Event",
      bookingIds: eligibleBookingIds,
      totalAmount: totalPending,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      completedAt: null,
      completedBy: null,
      paymentReference: null,
    });

    payoutId = payoutRef.id;

    const bookingBatch = db.batch();
    for (const bookingId of eligibleBookingIds) {
      bookingBatch.update(db.collection("bookings").doc(bookingId), {
        payoutId,
        payoutStatus: "pending",
      });
    }
    await bookingBatch.commit();

    logger.info(`[EventCompletion] Created payout ${payoutId} for ₹${totalPending} for event ${eventId}`);
  } else {
    logger.info(`[EventCompletion] No payout created for event ${eventId}.`);
  }

  // =========================================================
  // 5. Mark event completed
  // =========================================================
  await eventDoc.ref.update({
    status: "completed",
    payoutProcessed: true,
    completedAt: FieldValue.serverTimestamp(),
  });

  // =========================================================
  // 6. Send emails / notifications — three cases only, all driven
  //    by real booking data (hasBookings / hasPayout), never by
  //    eventData.isFree or eventData.price.
  // =========================================================
  try {
    const transporter = getTransporter();

    if (transporter) {
      const eventTitle = eventData.title || "Your Event";
      const hostName = eventData.creatorName || hostData.displayName || "Host";

      if (hostDoc.exists && hostDoc.data()?.email) {
        const hostEmail = hostDoc.data().email;

        let hostBody;
        let hostNotificationBody;

        if (!hasBookings) {
          // No one booked — free or paid, doesn't matter, nothing to pay out.
          hostBody = `
            <h2 style="color:#000000;font-size:20px;font-weight:600;margin:0 0 16px 0;">Hello ${hostName},</h2>
            <p style="color:#4B5563;font-size:15px;line-height:24px;margin:0 0 30px 0;">
              Your event "${eventTitle}" has ended.
              <br><br>
              Unfortunately, no one booked this event, so there are no earnings or payout associated with it.
              <br><br>
              Thank you for hosting on TheyDi!
            </p>
          `;
          hostNotificationBody = `"${eventTitle}" has ended with no bookings.`;
        } else if (hasPayout) {
          // Real money is owed.
          hostBody = `
            <h2 style="color:#000000;font-size:20px;font-weight:600;margin:0 0 16px 0;">Hello ${hostName},</h2>
            <p style="color:#4B5563;font-size:15px;line-height:24px;margin:0 0 30px 0;">
              Your event "${eventTitle}" has been successfully completed.
              <br><br>
              Your payout of ₹${totalPending.toFixed(0)} is being reviewed and will be transferred to your registered bank/UPI account manually by our team.
              <br><br>
              Thank you for hosting on TheyDi!
            </p>
          `;
          hostNotificationBody = `"${eventTitle}" is now marked as completed. Payout of ₹${totalPending.toFixed(0)} pending.`;
        } else {
          // Bookings exist (free RSVPs, or paid bookings that net to ₹0) but nothing is owed.
          hostBody = `
            <h2 style="color:#000000;font-size:20px;font-weight:600;margin:0 0 16px 0;">Hello ${hostName},</h2>
            <p style="color:#4B5563;font-size:15px;line-height:24px;margin:0 0 30px 0;">
              Your event "${eventTitle}" has been successfully completed.
              <br><br>
              Thank you for hosting on TheyDi!
            </p>
          `;
          hostNotificationBody = `"${eventTitle}" is now marked as completed.`;
        }

        await transporter.sendMail({
          from: `"TheyDi" <${process.env.GMAIL_USER}>`,
          to: hostEmail,
          subject: `✅ Event Completed — ${eventTitle}`,
          html: getBaseEmailHtml(`✅ Event Completed — ${eventTitle}`, hostBody),
        });

        await db.collection("users").doc(hostUid).collection("notifications").add({
          title: "✅ Event completed",
          body: hostNotificationBody,
          type: "system",
          eventId,
          createdAt: FieldValue.serverTimestamp(),
          isRead: false,
        });
      }

      // Attendee emails — unchanged, never mentioned payouts anyway.
      for (const uid of attendeeUids) {
        const userDoc = await db.collection("users").doc(uid).get();
        if (userDoc.exists && userDoc.data()?.email) {
          const attendeeName = userDoc.data().displayName || "there";
          const attendeeEmail = userDoc.data().email;

          const attendeeBody = `
            <h2 style="color:#000000;font-size:20px;font-weight:600;margin:0 0 16px 0;">Hello ${attendeeName},</h2>
            <p style="color:#4B5563;font-size:15px;line-height:24px;margin:0 0 30px 0;">
              "${eventTitle}" hosted by ${hostName} has ended.
              <br><br>
              Thank you for being there! We hope you had a wonderful experience.
              <br><br>
              If you enjoyed the event, consider leaving a review for the host on TheyDi.
            </p>
          `;

          await transporter.sendMail({
            from: `"TheyDi" <${process.env.GMAIL_USER}>`,
            to: attendeeEmail,
            subject: `🙌 "${eventTitle}" has ended`,
            html: getBaseEmailHtml(`🙌 "${eventTitle}" has ended`, attendeeBody),
          });

          await db.collection("users").doc(uid).collection("notifications").add({
            title: "Event ended",
            body: `Hope you enjoyed "${eventTitle}"!`,
            type: "system",
            eventId,
            createdAt: FieldValue.serverTimestamp(),
            isRead: false,
          });
        }
      }
    }
  } catch (err) {
    logger.error("[EventCompletion] Error sending completion emails:", err);
  }

  return { success: true, bookingsProcessed, totalPending, hasPayout };
}

const processPayoutForEventId = processEventCompletion;

const MAX_OTP_ATTEMPTS = 5;

exports.sendOtp = onCall({ region: REGION }, async (request) => {
  try {
    const { email } = request.data || {};
    if (!email) throw new HttpsError("invalid-argument", "Email is required");
    const emailTrimmed = email.trim().toLowerCase();

    try {
      await admin.auth().getUserByEmail(emailTrimmed);
    } catch {
      throw new HttpsError("not-found", "No account found with this email");
    }

    const transporter = getTransporter();
    if (!transporter) {
      throw new HttpsError("internal", "Email service is not configured.");
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await db.collection("password_reset_otps").doc(emailTrimmed).set({
      email: emailTrimmed, otp, expiresAt, verified: false, attempts: 0,
    });

    const emailBody = `
      <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello there,</h2>
      <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0 0 30px 0;">
        Here is your secure verification code. Please use this to complete your current action in the TheyDi app. This code will expire in 10 minutes.
      </p>
      <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #F9FAFB; border-radius: 12px; border: 1px solid #E5E7EB;">
        <tr>
          <td align="center" style="padding: 24px;">
            <h1 style="color: #10B981; font-size: 38px; font-weight: 700; margin: 0; letter-spacing: 12px; font-family: monospace;">${otp}</h1>
          </td>
        </tr>
      </table>
      <p style="color: #9CA3AF; font-size: 13px; line-height: 20px; margin: 30px 0 0 0; text-align: center;">
        If you didn't request this email, please ignore it or contact TheyDi support immediately if you feel your account is at risk.
      </p>
    `;
    const html = getBaseEmailHtml("Your TheyDi Verification Code", emailBody);

    await transporter.sendMail({
      from: `"TheyDi" <${process.env.GMAIL_USER}>`,
      to: emailTrimmed, subject: "Password Reset OTP",
      text: `Your OTP is ${otp}. Valid for 10 mins.`, html: html,
    });

    return { success: true, message: "OTP sent" };
  } catch (error) {
    logger.error("Error sending OTP", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error.message || "Error sending OTP");
  }
});

exports.verifyOtp = onCall({ region: REGION }, async (request) => {
  try {
    const { email, otp } = request.data || {};
    if (!email || !otp) throw new HttpsError("invalid-argument", "Missing fields");

    const emailTrimmed = email.trim().toLowerCase();
    const docRef = db.collection("password_reset_otps").doc(emailTrimmed);
    const doc = await docRef.get();
    if (!doc.exists) throw new HttpsError("not-found", "No active OTP request");

    const data = doc.data();
    if (data.expiresAt.toDate() < new Date()) {
      throw new HttpsError("deadline-exceeded", "OTP expired");
    }
    if ((data.attempts || 0) >= MAX_OTP_ATTEMPTS) {
      throw new HttpsError("resource-exhausted", "Too many attempts. Please request a new OTP.");
    }
    if (data.otp !== otp.trim()) {
      await docRef.update({ attempts: FieldValue.increment(1) });
      throw new HttpsError("invalid-argument", "Invalid OTP");
    }

    const verifiedExpiresAt = new Date(Date.now() + 5 * 60 * 1000);
    await docRef.update({ verified: true, verifiedExpiresAt });

    return { success: true, message: "OTP verified" };
  } catch (error) {
    logger.error("Error verifying OTP", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error.message || "Error verifying OTP");
  }
});

exports.resetPassword = onCall({ region: REGION }, async (request) => {
  try {
    const { email, password } = request.data || {};
    if (!email || !password) throw new HttpsError("invalid-argument", "Missing fields");

    const emailTrimmed = email.trim().toLowerCase();
    const docRef = db.collection("password_reset_otps").doc(emailTrimmed);
    const doc = await docRef.get();
    if (!doc.exists) throw new HttpsError("not-found", "Session not found");

    const data = doc.data();
    if (!data.verified || data.verifiedExpiresAt.toDate() < new Date()) {
      await db.collection("password_reset_logs").add({
        email: emailTrimmed, resetAt: FieldValue.serverTimestamp(),
        success: false, reason: "Verification expired or invalid",
      });
      throw new HttpsError("failed-precondition", "Verification expired or invalid");
    }

    const user = await admin.auth().getUserByEmail(emailTrimmed);
    await admin.auth().updateUser(user.uid, { password });

    await db.collection("password_reset_logs").add({
      email: emailTrimmed, resetAt: FieldValue.serverTimestamp(), success: true,
    });

    await docRef.delete();
    return { success: true, message: "Password updated" };
  } catch (error) {
    logger.error("Error resetting password", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error.message || "Error resetting password");
  }
});

exports.sendSignupOtpEmail = onCall({ region: REGION }, async (request) => {
  try {
    const { toEmail, toName, otp } = request.data;
    if (!toEmail || !otp) throw new HttpsError("invalid-argument", "Missing email or OTP");

    const transporter = getTransporter();
    if (!transporter) throw new HttpsError("internal", "Email service not configured.");

    const emailBody = `
      <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello ${toName || 'there'},</h2>
      <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0 0 30px 0;">
        Here is your verification code to complete your TheyDi registration. This code will expire in 10 minutes.
      </p>
      <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #F9FAFB; border-radius: 12px; border: 1px solid #E5E7EB;">
        <tr>
          <td align="center" style="padding: 24px;">
            <h1 style="color: #10B981; font-size: 38px; font-weight: 700; margin: 0; letter-spacing: 12px; font-family: monospace;">${otp}</h1>
          </td>
        </tr>
      </table>
    `;
    const html = getBaseEmailHtml("Your TheyDi Verification Code", emailBody);

    await transporter.sendMail({
      from: `"TheyDi" <${process.env.GMAIL_USER}>`,
      to: toEmail, subject: "TheyDi Registration OTP",
      text: `Your OTP is ${otp}.`, html: html,
    });
    return { success: true };
  } catch (e) {
    logger.error("sendSignupOtpEmail failed", e);
    throw new HttpsError("internal", e.message);
  }
});

exports.sendSystemNotificationEmail = onCall({ region: REGION }, async (request) => {
  try {
    const { toEmail, toName, title, message } = request.data;
    if (!toEmail || !message) throw new HttpsError("invalid-argument", "Missing fields");

    const transporter = getTransporter();
    if (!transporter) throw new HttpsError("internal", "Email service not configured.");

    let cleanMessage = message.replace(new RegExp(`^Hi ${toName},?\\s*\\n*`, 'i'), '');

    const emailBody = `
      <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello ${toName || 'there'},</h2>
      <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0 0 30px 0; white-space: pre-wrap;">
        ${cleanMessage}
      </p>
    `;
    const html = getBaseEmailHtml(title || "TheyDi Notification", emailBody);

    await transporter.sendMail({
      from: `"TheyDi" <${process.env.GMAIL_USER}>`,
      to: toEmail, subject: title || "New Notification from TheyDi",
      text: cleanMessage, html: html,
    });
    return { success: true };
  } catch (e) {
    logger.error("sendSystemNotificationEmail failed", e);
    throw new HttpsError("internal", e.message);
  }
});

exports.processAutomaticPayouts = onSchedule(
  "every 4 hours",
  async (event) => {
    logger.info("[Cron] Starting processAutomaticPayouts...");

    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    try {
      const eventsSnap = await db
        .collection("events")
        .where("payoutProcessed", "==", false)
        .where("endTime", "<=", now)
        .get();

      if (eventsSnap.empty) {
        logger.info("[Cron] No completed events awaiting payout.");
        return;
      }

      logger.info(
        `[Cron] Found ${eventsSnap.size} events awaiting automatic payout.`
      );

      for (const doc of eventsSnap.docs) {
        try {
          const eventData = doc.data();

          // NEVER process cancelled events
          if (eventData.status === "cancelled") {
            logger.info(
              `[Cron] Skipping cancelled event ${doc.id}.`
            );
            continue;
          }

          await processPayoutForEventId(doc.id);
        } catch (e) {
          logger.error(
            `[Cron] Failed to process payout for event ${doc.id}:`,
            e
          );
        }
      }
    } catch (e) {
      logger.error("[Cron] Error querying events:", e);
    }

    logger.info("[Cron] Finished processAutomaticPayouts.");
  }
);

exports.cancelEventAndRefund = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in.");

  const { eventId } = request.data;
  if (!eventId) throw new HttpsError("invalid-argument", "Missing eventId.");

  const db = admin.firestore();
  const eventRef = db.collection("events").doc(eventId);
  const eventDoc = await eventRef.get();

  if (!eventDoc.exists) throw new HttpsError("not-found", "Event not found.");

  const eventData = eventDoc.data();
  if (eventData.creatorUid !== request.auth.uid) {
    throw new HttpsError("permission-denied", "Only the host can cancel this event.");
  }
  if (eventData.status === "cancelled") {
    throw new HttpsError("failed-precondition", "Event is already cancelled.");
  }

  if (eventData.dateTime) {
    let eventTime;
    if (eventData.dateTime.toDate) {
      eventTime = eventData.dateTime.toDate().getTime();
    } else {
      eventTime = new Date(eventData.dateTime).getTime();
    }
    const now = Date.now();
    const hoursDifference = (eventTime - now) / (1000 * 60 * 60);
    if (hoursDifference < 48) {
      throw new HttpsError("failed-precondition", "Events can only be cancelled at least 48 hours before the start time.");
    }
  }

  const razorpay = getRazorpay();
  const transporter = getTransporter();

  const bookingsSnap = await db.collection("bookings")
    .where("eventId", "==", eventId)
    .where("status", "==", "confirmed")
    .get();

  let refundCount = 0;

  for (const bookingDoc of bookingsSnap.docs) {
    const bData = bookingDoc.data();
    const transactionId = bData.transactionId;
    const isPaidBooking = bData.totalAmount > 0 && transactionId;

    if (isPaidBooking && razorpay) {
      try {
        await razorpay.payments.refund(transactionId, {
          speed: "normal",
          notes: { reason: "Event cancelled by host", bookingId: bookingDoc.id },
        });

        await bookingDoc.ref.update({ status: "refunded" });
        refundCount++;

        const userDoc = await db.collection("users").doc(bData.userId).get();
        if (userDoc.exists && userDoc.data().email && transporter) {
          const attendeeName = userDoc.data().displayName || "there";
          const attendeeEmail = userDoc.data().email;

          const refundBody = `
            <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello ${attendeeName},</h2>
            <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0 0 30px 0; white-space: pre-wrap;">The event "${eventData.title}" was cancelled by the host.\n\nA full refund of ₹${bData.totalAmount.toFixed(0)} has been initiated and will reflect in your original payment method in 5-7 business days.</p>
          `;

          await transporter.sendMail({
            from: `"TheyDi" <${process.env.GMAIL_USER}>`,
            to: attendeeEmail,
            subject: `Event Cancelled & Refund Initiated — ${eventData.title}`,
            html: getBaseEmailHtml(`Event Cancelled & Refund Initiated`, refundBody),
          });

          await db.collection("users").doc(bData.userId).collection("notifications").add({
            title: 'Refund Initiated',
            body: `"${eventData.title}" was cancelled. ₹${bData.totalAmount.toFixed(0)} is being refunded in full.`,
            type: 'system', eventId: eventId,
            createdAt: FieldValue.serverTimestamp(), isRead: false,
          });
        }
      } catch (err) {
        logger.error(`Refund failed for booking ${bookingDoc.id}`, err);
        await bookingDoc.ref.update({
          status: "refund_failed",
          refundFailureReason: err.message || "Razorpay refund API error",
        });
      }
    } else if (isPaidBooking && !razorpay) {
      logger.error(
        `[cancelEventAndRefund] Razorpay not configured — cannot refund paid booking ${bookingDoc.id} (₹${bData.totalAmount}) for event ${eventId}.`
      );

      await bookingDoc.ref.update({
        status: "refund_failed",
        refundFailureReason: "Razorpay not configured on server",
      });

      await db.collection("admin_alerts").add({
        type: "refund_config_error",
        message: `Razorpay not configured — booking ${bookingDoc.id} for event ${eventId} needs a manual refund of ₹${bData.totalAmount}.`,
        bookingId: bookingDoc.id, eventId,
        createdAt: FieldValue.serverTimestamp(), resolved: false,
      });
    } else {
      await bookingDoc.ref.update({ status: "cancelled" });

      const userDoc = await db.collection("users").doc(bData.userId).get();
      if (userDoc.exists && userDoc.data().email && transporter) {
        const attendeeName = userDoc.data().displayName || "there";
        const attendeeEmail = userDoc.data().email;
        const cancelBody = `
          <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello ${attendeeName},</h2>
          <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0 0 30px 0; white-space: pre-wrap;">The event "${eventData.title}" has been cancelled by the host.</p>
        `;
        await transporter.sendMail({
          from: `"TheyDi" <${process.env.GMAIL_USER}>`,
          to: attendeeEmail,
          subject: `Event Cancelled — ${eventData.title}`,
          html: getBaseEmailHtml(`Event Cancelled`, cancelBody),
        });

        await db.collection("users").doc(bData.userId).collection("notifications").add({
          title: 'Event Cancelled',
          body: `"${eventData.title}" has been cancelled.`,
          type: 'system', eventId: eventId,
          createdAt: FieldValue.serverTimestamp(), isRead: false,
        });
      }
    }
  }

  await eventRef.update({ status: "cancelled" });
  return { success: true, refundsProcessed: refundCount };
});

exports.processRefund = onDocumentCreated({ document: "refunds/{refundId}", region: REGION }, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const refundData = snapshot.data();
  if (refundData.status !== "pending") return;

  const razorpay = getRazorpay();
  const transporter = getTransporter();

  try {
    const bookingsSnap = await db.collection("bookings")
      .where("eventId", "==", refundData.eventId)
      .where("userId", "==", refundData.userId)
      .get();

    if (bookingsSnap.empty) {
      logger.error(`No booking found for refund ${event.params.refundId}`);
      await snapshot.ref.update({ status: "failed", error: "No booking found" });
      return;
    }

    const sortedDocs = bookingsSnap.docs.sort((a, b) => {
      const aTime = a.data().createdAt?.toMillis() || 0;
      const bTime = b.data().createdAt?.toMillis() || 0;
      return bTime - aTime;
    });

    const bookingDoc = sortedDocs[0];
    const bookingData = bookingDoc.data();
    const transactionId = bookingData.transactionId;

    if (transactionId && razorpay && refundData.refundAmount > 0) {
      const refundAmountPaise = Math.round(refundData.refundAmount * 100);
      await razorpay.payments.refund(transactionId, {
        amount: refundAmountPaise,
        speed: "normal",
        notes: { reason: "Attendee left event", refundId: event.params.refundId },
      });
    }

    await snapshot.ref.update({ status: "processed", processedAt: FieldValue.serverTimestamp() });
    await bookingDoc.ref.update({ status: "cancelled_by_attendee" });

    const userDoc = await db.collection("users").doc(refundData.userId).get();
    if (userDoc.exists && userDoc.data().email && transporter) {
      const attendeeName = userDoc.data().displayName || "there";
      const attendeeEmail = userDoc.data().email;

      const eventDoc = await db.collection("events").doc(refundData.eventId).get();
      const eventTitle = eventDoc.exists ? eventDoc.data().title : "the event";

      const refundBody = `
        <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello ${attendeeName},</h2>
        <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0 0 30px 0; white-space: pre-wrap;">You have successfully left "${eventTitle}".\n\nA partial refund of ₹${refundData.refundAmount} (after a 10% cancellation fee) has been initiated and will reflect in your original payment method in 5-7 business days.</p>
      `;
      await transporter.sendMail({
        from: `"TheyDi" <${process.env.GMAIL_USER}>`,
        to: attendeeEmail,
        subject: `Event Cancellation & Refund — ${eventTitle}`,
        html: getBaseEmailHtml(`Event Cancellation & Refund`, refundBody),
      });
    }
  } catch (error) {
    logger.error(`Error processing refund ${event.params.refundId}:`, error);
    const errMsg = error.message || (error.error && error.error.description) || error.toString();
    await snapshot.ref.update({ status: "failed", error: errMsg });
  }
});

exports.sendPushOnNotification = onDocumentCreated(
  { document: "users/{uid}/notifications/{notifId}", region: REGION },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const uid = event.params.uid;

    try {
      const userDoc = await db.collection("users").doc(uid).get();
      const token = userDoc.exists ? userDoc.data().fcmToken : null;

      if (!token) {
        logger.info(`[Push] No fcmToken for user ${uid}, skipping push.`);
        return;
      }

      const response = await admin.messaging().send({
        token,
        notification: {
          title: data.title || "TheyDi",
          body: data.body || "",
          imageUrl: data.imageUrl || undefined,
        },
        data: {
          type: data.type || "",
          title: data.title || "",   // ← add
          body: data.body || "",  
          eventId: data.eventId || "",
          fromUid: data.fromUid || "",
          circleId: data.circleId || "",
          chatId: data.chatId || "",
          imageUrl: data.imageUrl || "",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            imageUrl: data.imageUrl || undefined,
          },
        },
      });

      logger.info(`[Push] Sent to user ${uid}: ${response}`);
    } catch (err) {
      logger.error(`[Push] Failed to send push to user ${uid}:`, err);

      if (err.code === "messaging/registration-token-not-registered") {
        await db.collection("users").doc(uid).update({
          fcmToken: FieldValue.delete(),
        }).catch((cleanupErr) => {
          logger.error(`[Push] Failed to clear stale token for ${uid}:`, cleanupErr);
        });
      }
    }
  }
);
