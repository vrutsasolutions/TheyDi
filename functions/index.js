const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const Razorpay = require("razorpay");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

// Initialize Firebase Admin ONCE, at the top.
admin.initializeApp();
const db = admin.firestore();

// All functions live in this region so client base URLs stay consistent.
const REGION = "asia-south1";

// Email Base HTML Template
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
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_SECRET_KEY;
  if (!keyId || !keySecret) {
    logger.warn("Razorpay keys are missing from environment variables.");
    return null;
  }
  return new Razorpay({
    key_id: keyId,
    key_secret: keySecret,
  });
}

// Nodemailer transporter — credentials come from environment variables.
// Local testing: set them in functions/.env.local
//   GMAIL_USER=you@gmail.com
//   GMAIL_APP_PASSWORD=xxxxxxxxxxxxxxxx
// Production: set them as Secret Manager secrets
//   firebase functions:secrets:set GMAIL_USER
//   firebase functions:secrets:set GMAIL_APP_PASSWORD
function getTransporter() {
  const user = process.env.GMAIL_USER;
  const pass = process.env.GMAIL_APP_PASSWORD;
  if (!user || !pass) {
    logger.warn("Gmail credentials are missing from environment variables.");
    return null;
  }
  return nodemailer.createTransport({
    service: "gmail",
    auth: { user, pass },
  });
}

// ---------------------------------------------------------------------------
// Cashfree Payout Helpers
// ---------------------------------------------------------------------------

/**
 * Returns the Cashfree Payout API base URL based on the CASHFREE_ENVIRONMENT env variable.
 */
function getCashfreeBaseUrl() {
  const env = (process.env.CASHFREE_ENVIRONMENT || process.env.CASHFREE_PAYOUT_ENV || "").toUpperCase();
  return env === "PRODUCTION"
    ? "https://api.cashfree.com/payout"
    : "https://sandbox.cashfree.com/payout";
}

/**
 * Fetches a Cashfree Payout bearer token for v1 endpoints like addBeneficiary.
 */
async function getCashfreePayoutToken() {
  const clientId = process.env.CASHFREE_PAYOUT_CLIENT_ID;
  const clientSecret = process.env.CASHFREE_PAYOUT_CLIENT_SECRET;
  const env = (process.env.CASHFREE_ENVIRONMENT || process.env.CASHFREE_PAYOUT_ENV || "").toUpperCase();
  const authUrl = env === "PRODUCTION"
    ? "https://payout-api.cashfree.com/payout/v1/authorize"
    : "https://payout-gamma.cashfree.com/payout/v1/authorize";

  const res = await fetch(authUrl, {
    method: "POST",
    headers: {
      "X-Client-Id": clientId,
      "X-Client-Secret": clientSecret,
      "Content-Type": "application/json",
    },
  });
  const data = await res.json();
  if (data.status !== "SUCCESS" || !data.data?.token) {
    throw new Error("Cashfree authorization failed: " + (data.message || JSON.stringify(data)));
  }
  return data.data.token;
}

/**
 * Returns Cashfree Payout v2 headers including client ID, client secret, and API version.
 */
function getCashfreeHeaders() {
  const clientId = process.env.CASHFREE_PAYOUT_CLIENT_ID;
  const clientSecret = process.env.CASHFREE_PAYOUT_CLIENT_SECRET;
  const apiVersion = process.env.CASHFREE_PAYOUT_API_VERSION || "2024-01-01";
  if (!clientId || !clientSecret) {
    throw new Error("Cashfree Payout credentials are not configured in environment variables.");
  }
  return {
    "x-client-id": clientId,
    "x-client-secret": clientSecret,
    "x-api-version": apiVersion,
    "Content-Type": "application/json",
  };
}

/**
 * 1. createOrder
 * Called from Flutter to create a Razorpay Order ID securely.
 */
exports.createOrder = onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in to create an order.");
    }

    const razorpay = getRazorpay();
    if (!razorpay) {
      throw new HttpsError("internal", "Razorpay is not configured on the server.");
    }

    const { amount, currency, receipt, notes } = request.data;

    if (!amount) {
      throw new HttpsError("invalid-argument", "The amount is required.");
    }

    try {
      const options = {
        amount: amount, // amount in smallest currency unit (paise)
        currency: currency || "INR",
        receipt: receipt || `rcptid_${Date.now()}`,
        notes: notes || {},
      };

      const order = await razorpay.orders.create(options);
      logger.info("Order created successfully", { orderId: order.id });

      return {
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
      };
    } catch (error) {
      logger.error("Error creating Razorpay order", error);
      throw new HttpsError("internal", "Failed to create Razorpay order.");
    }
  }
);

/**
 * 2. verifyPayment
 * Called from Flutter after Razorpay UI succeeds.
 * Verifies the signature and writes the booking to Firestore.
 */
exports.verifyPayment = onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in to verify payment.");
    }

    const {
      razorpay_payment_id,
      razorpay_order_id,
      razorpay_signature,
      eventId,
      eventTitle,
      hostUid,
      amount,
      platformFee,
      totalAmount,
      paymentMethod,
      fromApproval,
    } = request.data;

    if (!razorpay_payment_id || !razorpay_order_id || !razorpay_signature) {
      throw new HttpsError("invalid-argument", "Missing payment verification parameters.");
    }

    const uid = request.auth.uid;
    let userName = request.auth.token.name || request.auth.token.email?.split("@")[0] || "User";

    const keySecret = process.env.RAZORPAY_SECRET_KEY;
    if (!keySecret) {
      throw new HttpsError("internal", "Razorpay secret key is not configured.");
    }

    // Verify Razorpay Signature using HMAC SHA256
    const body = razorpay_order_id + "|" + razorpay_payment_id;
    const expectedSignature = crypto
      .createHmac("sha256", keySecret)
      .update(body.toString())
      .digest("hex");

    if (expectedSignature !== razorpay_signature) {
      logger.error("Payment signature verification failed");
      throw new HttpsError("permission-denied", "Payment signature is invalid.");
    }

    try {
      // Check if webhook already processed this payment
      const existingPaymentRef = await db.collection("events").doc(eventId)
        .collection("attendeePayments").doc(uid).get();

      if (existingPaymentRef.exists && existingPaymentRef.data().status === "paid") {
        logger.info("Payment already processed by webhook. Skipping duplicate write.");
        return { success: true, message: "Payment already verified by webhook." };
      }

      // Fetch latest user details (optional)
      const userDoc = await db.collection("users").doc(uid).get();
      if (userDoc.exists) {
        const data = userDoc.data();
        userName = data.displayName || data.fullName || data.name || userName;
      }

      // Prepare Booking Data
      const bookingData = {
        eventId,
        eventTitle,
        userId: uid,
        userName,
        hostUid,
        amount,
        platformFee,
        totalAmount,
        status: "confirmed",
        paymentMethod: paymentMethod || "Unknown",
        transactionId: razorpay_payment_id,
        createdAt: FieldValue.serverTimestamp(),
        confirmedAt: FieldValue.serverTimestamp(),
      };

      // Run as a batch write for atomicity
      const batch = db.batch();

      // 1. Create Booking record
      const newBookingRef = db.collection("bookings").doc();
      batch.set(newBookingRef, bookingData);

      // 2. Add user to attendees array in event
      const eventRef = db.collection("events").doc(eventId);
      const eventUpdates = {
        attendeeUids: FieldValue.arrayUnion(uid),
      };
      if (fromApproval) {
        eventUpdates.approvedPendingPaymentUids = FieldValue.arrayRemove(uid);
      }
      batch.update(eventRef, eventUpdates);

      // 3. Mark attendeePayments as paid
      const paymentRef = eventRef.collection("attendeePayments").doc(uid);
      batch.set(paymentRef, {
        status: "paid",
        userName,
        transactionId: razorpay_payment_id,
        paymentMethod: paymentMethod || "Unknown",
        amount: totalAmount,
        paidAt: FieldValue.serverTimestamp(),
        eventId,
      }, { merge: true });

      // 4. Update user event count
      const userRef = db.collection("users").doc(uid);
      batch.set(userRef, {
        eventsAttended: FieldValue.increment(1),
      }, { merge: true });

      // 5. Create Payment history record in root 'payment' collection
      const globalPaymentRef = db.collection("payment").doc(razorpay_payment_id);
      batch.set(globalPaymentRef, {
        amount: amount || totalAmount || 0,
        createdAt: FieldValue.serverTimestamp(),
        currency: "INR",
        eventId: eventId,
        orderId: razorpay_order_id,
        paymentId: razorpay_payment_id,
        paymentMethod: paymentMethod || "Unknown",
        status: "Success",
        uid: uid,
        username: userName,
        verified: true,
      });

      await batch.commit();

      return { success: true, message: "Payment verified and booking confirmed." };
    } catch (error) {
      logger.error("Failed to process booking after payment validation", error);
      throw new HttpsError("internal", "Payment was verified but failed to write booking to database.");
    }
  }
);

/**
 * 3. razorpayWebhook
 * Called by Razorpay when an event (e.g., order.paid) occurs.
 * This acts as a reliable fallback in case the client app crashes or loses internet.
 */
exports.razorpayWebhook = onRequest(
  { region: REGION },
  async (req, res) => {
    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;

    if (webhookSecret) {
      const signature = req.headers["x-razorpay-signature"];
      if (!signature) {
        return res.status(400).send("No signature found");
      }

      const expectedSignature = crypto
        .createHmac("sha256", webhookSecret)
        .update(req.rawBody)
        .digest("hex");

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

        // Check if booking already exists (from client-side verifyPayment)
        const existingPaymentRef = await db.collection("events").doc(notes.eventId)
          .collection("attendeePayments").doc(notes.userId).get();

        if (existingPaymentRef.exists && existingPaymentRef.data().status === "paid") {
          logger.info("Payment already processed by client");
          return res.status(200).send("Already processed");
        }

        logger.info("Processing webhook for order.paid", { orderId: order.id, userId: notes.userId });

        const bookingData = {
          eventId: notes.eventId,
          eventTitle: notes.eventTitle || "Unknown Event",
          userId: notes.userId,
          userName: "User",
          hostUid: notes.hostUid,
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
        const eventUpdates = {
          attendeeUids: FieldValue.arrayUnion(notes.userId),
        };
        if (notes.fromApproval === "true") {
          eventUpdates.approvedPendingPaymentUids = FieldValue.arrayRemove(notes.userId);
        }
        batch.update(eventRef, eventUpdates);

        const paymentRef = eventRef.collection("attendeePayments").doc(notes.userId);
        batch.set(paymentRef, {
          status: "paid",
          userName: "User",
          transactionId: payment.id,
          paymentMethod: payment.method || "Unknown",
          amount: bookingData.totalAmount,
          paidAt: FieldValue.serverTimestamp(),
          eventId: notes.eventId,
        }, { merge: true });

        const userRef = db.collection("users").doc(notes.userId);
        batch.update(userRef, {
          eventsAttended: FieldValue.increment(1),
        });

        const globalPaymentRef = db.collection("payment").doc(payment.id);
        batch.set(globalPaymentRef, {
          amount: bookingData.totalAmount,
          createdAt: FieldValue.serverTimestamp(),
          currency: "INR",
          eventId: notes.eventId,
          orderId: order.id,
          paymentId: payment.id,
          paymentMethod: payment.method || "Unknown",
          status: "Success",
          uid: notes.userId,
          username: "User",
          verified: true,
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

/**
 * 4. cashfreePayoutWebhook
 * Receives payout status events from Cashfree and updates booking records in Firestore.
 * Register this URL in your Cashfree Merchant Dashboard → Payouts → Webhooks.
 */
exports.cashfreePayoutWebhook = onRequest(
  { region: REGION },
  async (req, res) => {
    const secret = process.env.CASHFREE_PAYOUT_WEBHOOK_SECRET || process.env.CASHFREE_PAYOUT_CLIENT_SECRET;

    if (secret) {
      const signature = req.headers["x-webhook-signature"];
      if (!signature) {
        return res.status(400).send("No signature found");
      }
      const expectedSignature = crypto
        .createHmac("sha256", secret)
        .update(req.rawBody)
        .digest("base64");
      if (expectedSignature !== signature) {
        logger.error("[Cashfree Webhook] Signature verification failed");
        return res.status(400).send("Invalid signature");
      }
    } else {
      logger.warn("[Cashfree Webhook] CASHFREE_PAYOUT_WEBHOOK_SECRET/CLIENT_SECRET not set. Skipping signature check (not safe for production).");
    }

    try {
      const event = req.body;
      const eventType = event.event;
      const transferData = event.data || {};
      // Cashfree may nest the transferId under data.transfer or at top level (transferId or transfer_id)
      const transferId = transferData.transfer?.transferId || transferData.transferId || transferData.transfer_id || transferData.cf_transfer_id;

      logger.info(`[Cashfree Webhook] Event: ${eventType}, transferId: ${transferId}`);

      if (!transferId) {
        return res.status(200).send("OK");
      }

      // Find the booking using the transferId stored at payout initiation
      const bookingsSnap = await db.collection("bookings")
        .where("cashfreeTransferId", "==", transferId)
        .limit(1)
        .get();

      if (bookingsSnap.empty) {
        logger.warn(`[Cashfree Webhook] No booking found for transferId: ${transferId}`);
        return res.status(200).send("OK");
      }

      const bookingDoc = bookingsSnap.docs[0];
      const bookingData = bookingDoc.data();

      if (eventType === "TRANSFER_SUCCESS") {
        await bookingDoc.ref.update({
          payoutStatus: "completed",
          payoutCompletedAt: FieldValue.serverTimestamp(),
        });
        logger.info(`[Cashfree Webhook] Payout completed for booking: ${bookingDoc.id}`);

      } else if (eventType === "TRANSFER_FAILED" || eventType === "TRANSFER_REVERSED") {
        const failureReason = transferData.transfer?.reason || transferData.reason || "Unknown reason";

        await bookingDoc.ref.update({
          payoutStatus: "failed",
          payoutFailedAt: FieldValue.serverTimestamp(),
          payoutFailureReason: failureReason,
        });
        logger.warn(`[Cashfree Webhook] Payout ${eventType} for booking: ${bookingDoc.id}. Reason: ${failureReason}`);

        // Notify the host via email and in-app notification
        const hostUid = bookingData.hostUid;
        if (hostUid) {
          try {
            const hostDoc = await db.collection("users").doc(hostUid).get();
            const hostData = hostDoc.data();
            if (hostData) {
              if (hostData.email) {
                const transporter = getTransporter();
                if (transporter) {
                  const emailBody = `
                    <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello ${hostData.displayName || "Host"},</h2>
                    <h3 style="color: #10B981; font-size: 18px; margin: 0 0 10px 0;">Action Required: Payout Failed ⚠️</h3>
                    <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0;">
                      Unfortunately, your payout for a booking in your event failed.<br><br>
                      <strong>Reason from bank:</strong> ${failureReason}.<br><br>
                      Please update your bank details in the TheyDi app as soon as possible so we can safely retry your payment.
                    </p>
                  `;
                  await transporter.sendMail({
                    from: `"TheyDi Team" <${process.env.GMAIL_USER}>`,
                    to: hostData.email,
                    subject: "Action Required: Payout Failed ⚠️",
                    text: `Hi ${hostData.displayName || "Host"},\n\nYour payout for a booking failed.\n\nReason: ${failureReason}.\n\nPlease update your bank details in the TheyDi app.\n\nThank you,\nTheyDi Team`,
                    html: getBaseEmailHtml("Action Required: Payout Failed", emailBody),
                  });
                }
              }

              await db.collection("notifications").add({
                toUid: hostUid,
                title: "Payout Failed ⚠️",
                body: `Your bank rejected a payout. Reason: ${failureReason}. Please update your account details.`,
                type: "payout_failed",
                eventId: bookingData.eventId,
                createdAt: FieldValue.serverTimestamp(),
                isRead: false,
              });
            }
          } catch (notifyErr) {
            logger.error("[Cashfree Webhook] Failed to send host failure notification:", notifyErr);
          }
        }
      }

      return res.status(200).send("OK");
    } catch (error) {
      logger.error("[Cashfree Webhook] Error processing event:", error);
      return res.status(500).send("Internal Server Error");
    }
  }
);

/**
 * 5. setupHostCashfreeBeneficiary
 * Registers a host as a Cashfree Payout beneficiary using their bank or UPI details.
 * Replaces the former createRazorpayXContact function.
 */
exports.setupHostCashfreeBeneficiary = onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in.");

    const uid = request.auth.uid;
    const { payoutMethod, upiId, name, ifsc, accountNumber, email, mobile, legalName } = request.data;
    const isUpi = payoutMethod === "upi";

    if (isUpi) {
      if (!upiId) throw new HttpsError("invalid-argument", "Missing UPI ID.");
    } else {
      if (!name || !ifsc || !accountNumber) throw new HttpsError("invalid-argument", "Missing bank details.");
    }

    // Fetch user doc to get stored email/phone if not explicitly passed in payload
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data() || {};

    // Use pay_ + Firebase UID as the Cashfree beneId — recognizable and unique per host
    const beneId = `pay_${uid}`;
    const beneName = name || legalName || userData.name || userData.displayName || "Host";
    const beneEmail = email || userData.email || request.auth.token.email || "host@example.com";
    const benePhone = mobile || userData.mobile || userData.phone || userData.phoneNumber || "9999999999";
    const transferMode = isUpi ? "upi" : "imps";

    const payload = {
      beneId,
      name: beneName,
      email: beneEmail,
      phone: benePhone,
      address1: "India",
    };

    if (isUpi) {
      payload.vpa = upiId;
    } else {
      payload.bankAccount = accountNumber;
      payload.ifsc = ifsc;
    }

    try {
      const token = await getCashfreePayoutToken();
      const env = (process.env.CASHFREE_ENVIRONMENT || process.env.CASHFREE_PAYOUT_ENV || "").toUpperCase();
      const baseUrl = env === "PRODUCTION"
        ? "https://payout-api.cashfree.com/payout/v1"
        : "https://payout-gamma.cashfree.com/payout/v1";

      logger.info(`[Cashfree] Updating beneficiary ${beneId} for UID: ${uid}`);

      // 1. Remove old beneficiary record if it exists so new bank details can be registered
      try {
        await fetch(`${baseUrl}/removeBeneficiary`, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ beneId }),
        });
      } catch (err) {
        logger.info(`[Cashfree] removeBeneficiary notice (ignored): ${err.message}`);
      }

      // 2. Add beneficiary with the updated bank details
      const res = await fetch(`${baseUrl}/addBeneficiary`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      logger.info(`[Cashfree] addBeneficiary response: ${JSON.stringify(data)}`);

      const isSuccess = data.status === "SUCCESS" || data.subCode === "200" || data.subCode === 200;
      const alreadyExists = data.message?.toLowerCase().includes("already") || data.subCode === "409" || data.subCode === 409 || data.subCode === "422" || data.subCode === 422;

      if (!isSuccess && !alreadyExists) {
        throw new Error("Failed to set up Cashfree beneficiary: " + (data.message || JSON.stringify(data)));
      }

      // Persist ONLY non-sensitive identifier and payoutMode to Firestore
      // Explicitly delete any raw banking fields to ensure zero-storage of sensitive user data
      await db.collection("users").doc(uid).set({
        name: beneName,
        email: beneEmail,
        mobile: benePhone,
        cashfreeBeneId: beneId,
        payoutMode: transferMode,
        payoutSetupCompleted: true,
        accountNumber: FieldValue.delete(),
        ifsc: FieldValue.delete(),
        upiId: FieldValue.delete(),
        payoutDetails: FieldValue.delete(),
      }, { merge: true });

      // Clean up the temporary bank details document submitted from the app
      await db.collection("users").doc(uid).collection("private").doc("tempBankDetails").delete()
        .catch(err => logger.error("[Cashfree] Failed to delete tempBankDetails:", err));

      logger.info(`[Cashfree] Successfully onboarded beneficiary for UID: ${uid}`);
      return { success: true, beneId };
    } catch (e) {
      logger.error("[Cashfree] Error setting up beneficiary:", e);
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e.message || "Failed to set up Cashfree beneficiary.");
    }
  }
);

/**
 * 6. processPayoutForEventId (internal helper)
 * Processes Cashfree payouts for all confirmed bookings of a given event.
 * Called by both processCashfreePayout (manual trigger) and processAutomaticPayouts (cron).
 */
async function processPayoutForEventId(eventId) {
  if (!eventId) throw new HttpsError("invalid-argument", "Event ID required.");

  logger.info(`[CashfreePayout] Starting payout process for event: ${eventId}`);

  const eventDoc = await db.collection("events").doc(eventId).get();
  if (!eventDoc.exists) throw new HttpsError("not-found", "Event not found.");

  const eventData = eventDoc.data();

  const hostUid = eventData.creatorUid;
  const hostDoc = await db.collection("users").doc(hostUid).get();
  const hostData = hostDoc.data() || {};
  const beneId = hostData.cashfreeBeneId || `pay_${hostUid}`;
  const transferMode = hostData.payoutMode || "imps";

  if (!beneId) throw new HttpsError("failed-precondition", "Host has not set up a Cashfree payout account.");
  logger.info(`[CashfreePayout] Host beneId: ${beneId}, transferMode: ${transferMode}`);

  const allBookingsSnap = await db.collection("bookings")
    .where("eventId", "==", eventId)
    .get();

  logger.info(`[CashfreePayout] Total bookings in collection for event ${eventId}: ${allBookingsSnap.docs.length}`);

  const confirmedBookings = allBookingsSnap.docs.filter((d) => d.data().status === "confirmed");
  const alreadyProcessedBookings = confirmedBookings.filter((d) => ["completed", "processing"].includes(d.data().payoutStatus));
  const unpaidBookings = confirmedBookings.filter((d) => !["completed", "processing"].includes(d.data().payoutStatus));

  logger.info(`[CashfreePayout] Confirmed: ${confirmedBookings.length}, Already processed: ${alreadyProcessedBookings.length}, Unpaid: ${unpaidBookings.length}`);

  if (unpaidBookings.length === 0) {
    let msg = "No unpaid bookings found for this event.";
    if (allBookingsSnap.docs.length === 0) {
      msg = "No bookings found in database for this event. (Only paid bookings created through checkout can be paid out).";
    } else if (alreadyProcessedBookings.length > 0) {
      msg = `All ${alreadyProcessedBookings.length} booking payouts for this event have already been claimed/processed.`;
    }
    return { success: true, transfersProcessed: 0, totalTransferred: 0, message: msg };
  }

  const attendeeUids = eventData.attendeeUids || [];
  let transferCount = 0;
  let totalTransferred = 0;

  for (const doc of unpaidBookings) {
    const bData = doc.data();

    // Guard: ensure the user is still in the event's attendee list
    if (!attendeeUids.includes(bData.userId)) {
      logger.info(`[CashfreePayout] Skipping booking ${doc.id} — user no longer in attendee list.`);
      continue;
    }

    const baseAmount = bData.amount !== undefined ? bData.amount : (bData.totalAmount - (bData.platformFee || 0));
    // Cashfree expects amount as exact number in INR
    const payoutAmount = parseFloat(baseAmount.toFixed(2));

    if (payoutAmount <= 0) {
      logger.info(`[CashfreePayout] Skipping booking ${doc.id} — payout amount is ₹${payoutAmount}.`);
      continue;
    }

    // Unique transferId for idempotency (bookingId + timestamp, max 40 chars)
    const transferId = `td_${doc.id}_${Date.now().toString().slice(-6)}`;

    // Cashfree v2 Payout Transfer payload: References ONLY the beneficiary_id stored on Cashfree's vault.
    // Zero raw bank numbers or IFSC codes are stored or sent from our servers.
    const transferPayload = {
      transfer_id: transferId,
      transfer_amount: payoutAmount,
      transfer_currency: "INR",
      transfer_mode: transferMode.toLowerCase(),
      beneficiary_details: {
        beneficiary_id: beneId,
      },
      transfer_remarks: "TheyDi Event Payout",
    };

    try {
      logger.info(`[Cashfree v2 Payout] Initiating ₹${payoutAmount} ${transferMode} transfer for booking ${doc.id}`);
      const payoutRes = await fetch(`${getCashfreeBaseUrl()}/transfers`, {
        method: "POST",
        headers: getCashfreeHeaders(),
        body: JSON.stringify(transferPayload),
      });
      const payoutData = await payoutRes.json();

      logger.info(`[Cashfree v2 Payout] Transfer response for booking ${doc.id}: ${JSON.stringify(payoutData)}`);

      const isSuccess = payoutData.status === "RECEIVED" || payoutData.status === "SUCCESS" || payoutData.status === "PENDING" || payoutData.status_code === "RECEIVED";

      if (!isSuccess) {
        throw new Error("Transfer request failed: " + JSON.stringify(payoutData));
      }

      await doc.ref.update({
        payoutStatus: "processing",
        cashfreeTransferId: transferId,
        cfTransferId: payoutData.cf_transfer_id || payoutData.transfer_id || transferId,
      });
      transferCount++;
      totalTransferred += payoutAmount;
      logger.info(`[Cashfree v2 Payout] Transfer queued for booking ${doc.id}, transferId: ${transferId}`);
    } catch (e) {
      logger.error(`[Cashfree v2 Payout] Transfer failed for booking ${doc.id}:`, e);
    }
  }

  // Mark event as completed
  logger.info(`[CashfreePayout] Marking event ${eventId} as completed.`);
  await eventDoc.ref.update({ status: "completed", payoutProcessed: true });

  // ── Email & In-App Notifications for Event Completion ──
  try {
    const transporter = getTransporter();
    if (transporter) {
      const eventTitle = eventData.title || "Your Event";
      const hostName = eventData.creatorName || "The Host";

      // Notify Host
      if (hostDoc.exists && hostDoc.data().email) {
        const hostEmail = hostDoc.data().email;
        const hostBody = `
          <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello ${hostName},</h2>
          <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0 0 30px 0; white-space: pre-wrap;">Your event "${eventTitle}" has been successfully completed and payouts are being automatically processed.\n\nPlease check your bank account details in the TheyDi app immediately. You will receive your payout within 24 hours. If your account details are incorrect, you might lose the payment.\n\nThank you for hosting on TheyDi!</p>
        `;
        await transporter.sendMail({
          from: `"TheyDi" <${process.env.GMAIL_USER}>`,
          to: hostEmail,
          subject: `✅ Event Completed — ${eventTitle}`,
          html: getBaseEmailHtml(`✅ Event Completed — ${eventTitle}`, hostBody),
        });

        await db.collection("users").doc(hostUid).collection("notifications").add({
          title: "✅ Event completed",
          body: `"${eventTitle}" is now marked as completed.`,
          type: "system",
          eventId,
          createdAt: FieldValue.serverTimestamp(),
          isRead: false,
        });
      }

      // Notify Attendees
      for (const uid of attendeeUids) {
        const userDoc = await db.collection("users").doc(uid).get();
        if (userDoc.exists && userDoc.data().email) {
          const attendeeName = userDoc.data().displayName || "there";
          const attendeeEmail = userDoc.data().email;
          const attendeeBody = `
            <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello ${attendeeName},</h2>
            <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0 0 30px 0; white-space: pre-wrap;">"${eventTitle}" hosted by ${hostName} has ended.\n\nThank you for being there! We hope you had a wonderful experience.\n\nIf you enjoyed the event, consider leaving a review for the host on TheyDi.</p>
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
    logger.error("[CashfreePayout] Error sending completion emails:", err);
  }

  return { success: true, transfersProcessed: transferCount, totalTransferred };
}

exports.processCashfreePayout = onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in.");
    return await processPayoutForEventId(request.data.eventId);
  }
);

// Backward Compatibility Aliases
// exports.createRazorpayXContact = exports.setupHostCashfreeBeneficiary;
// exports.releaseHostPayoutsX = exports.processCashfreePayout;

// ---------------------------------------------------------------------------
// Forgot Password Flow
// ---------------------------------------------------------------------------

const MAX_OTP_ATTEMPTS = 5;

/**
 * 6. sendOtp
 */
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
      email: emailTrimmed,
      otp,
      expiresAt,
      verified: false,
      attempts: 0,
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
      to: emailTrimmed,
      subject: "Password Reset OTP",
      text: `Your OTP is ${otp}. Valid for 10 mins.`,
      html: html,
    });

    return { success: true, message: "OTP sent" };
  } catch (error) {
    logger.error("Error sending OTP", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error.message || "Error sending OTP");
  }
});

/**
 * 7. verifyOtp
 */
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

/**
 * 8. resetPassword
 */
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
        email: emailTrimmed,
        resetAt: FieldValue.serverTimestamp(),
        success: false,
        reason: "Verification expired or invalid",
      });
      throw new HttpsError("failed-precondition", "Verification expired or invalid");
    }

    const user = await admin.auth().getUserByEmail(emailTrimmed);
    await admin.auth().updateUser(user.uid, { password });

    await db.collection("password_reset_logs").add({
      email: emailTrimmed,
      resetAt: FieldValue.serverTimestamp(),
      success: true,
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
      to: toEmail,
      subject: "TheyDi Registration OTP",
      text: `Your OTP is ${otp}.`,
      html: html,
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

    // Remove any double greetings if the client still sends them accidentally
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
      to: toEmail,
      subject: title || "New Notification from TheyDi",
      text: cleanMessage,
      html: html,
    });
    return { success: true };
  } catch (e) {
    logger.error("sendSystemNotificationEmail failed", e);
    throw new HttpsError("internal", e.message);
  }
});

/**
 * 12. processAutomaticPayouts
 * Runs every 4 hours to find completed events that haven't been paid out yet and process their payouts.
 */
exports.processAutomaticPayouts = onSchedule("every 4 hours", async (event) => {
  logger.info("[Cron] Starting processAutomaticPayouts...");
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  try {
    const eventsSnap = await db.collection("events")
      .where("payoutProcessed", "==", false)
      .where("endTime", "<=", now)
      .get();
      
    if (eventsSnap.empty) {
      logger.info("[Cron] No completed events awaiting payout.");
      return;
    }

    logger.info(`[Cron] Found ${eventsSnap.size} events awaiting automatic payout.`);

    for (const doc of eventsSnap.docs) {
      try {
        await processPayoutForEventId(doc.id);
      } catch (e) {
        logger.error(`[Cron] Failed to process payout for event ${doc.id}:`, e);
      }
    }
  } catch (e) {
    logger.error("[Cron] Error querying events:", e);
  }
  
  logger.info("[Cron] Finished processAutomaticPayouts.");
});

/**
 * 13. cancelEventAndRefund
 * Cancels an event, refunds all confirmed bookings via Razorpay, and sends notification emails.
 */
exports.cancelEventAndRefund = onCall(
  { region: REGION },
  async (request) => {
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
    
    // Get all confirmed bookings
    const bookingsSnap = await db.collection("bookings")
      .where("eventId", "==", eventId)
      .where("status", "==", "confirmed")
      .get();
      
    let refundCount = 0;
    
    // Process refunds
    for (const bookingDoc of bookingsSnap.docs) {
      const bData = bookingDoc.data();
      const transactionId = bData.transactionId;
      
      if (bData.totalAmount > 0 && transactionId && razorpay) {
        try {
          await razorpay.payments.refund(transactionId, {
             speed: "normal",
             notes: { reason: "Event cancelled by host", bookingId: bookingDoc.id }
          });
          
          await bookingDoc.ref.update({ status: "refunded" });
          refundCount++;
          
          // Send refund email
          const userDoc = await db.collection("users").doc(bData.userId).get();
          if (userDoc.exists && userDoc.data().email && transporter) {
            const attendeeName = userDoc.data().displayName || "there";
            const attendeeEmail = userDoc.data().email;
            const refundBody = `
              <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello ${attendeeName},</h2>
              <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0 0 30px 0; white-space: pre-wrap;">The event "${eventData.title}" has been cancelled by the host.\n\nA full refund of ₹${bData.totalAmount} has been initiated and will reflect in your original payment method in 5-7 business days.</p>
            `;
            await transporter.sendMail({
              from: `"TheyDi" <${process.env.GMAIL_USER}>`,
              to: attendeeEmail,
              subject: `Event Cancelled & Refund Initiated — ${eventData.title}`,
              html: getBaseEmailHtml(`Event Cancelled & Refund Initiated`, refundBody),
            });
            
            await db.collection("users").doc(bData.userId).collection("notifications").add({
              title: 'Refund Initiated',
              body: `"${eventData.title}" was cancelled. ₹${bData.totalAmount} is being refunded.`,
              type: 'system',
              eventId: eventId,
              createdAt: FieldValue.serverTimestamp(),
              isRead: false
            });
          }
        } catch (err) {
          logger.error(`Refund failed for booking ${bookingDoc.id}`, err);
        }
      } else {
        // Free event booking or missing transactionId
        await bookingDoc.ref.update({ status: "cancelled" });
        // Send simple cancellation email
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
            type: 'system',
            eventId: eventId,
            createdAt: FieldValue.serverTimestamp(),
            isRead: false
          });
        }
      }
    }
    
    // Update event status
    await eventRef.update({ status: "cancelled" });
    
    return { success: true, refundsProcessed: refundCount };
  }
);

/**
 * Processes a refund when a new document is created in the refunds collection.
 * This happens when an attendee leaves a paid event.
 */
exports.processRefund = onDocumentCreated({ document: "refunds/{refundId}", region: REGION }, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const refundData = snapshot.data();
  if (refundData.status !== "pending") return;

  const razorpay = getRazorpay();
  const transporter = getTransporter();

  try {
    // 1. Find the booking for this user and event
    const bookingsSnap = await db.collection("bookings")
      .where("eventId", "==", refundData.eventId)
      .where("userId", "==", refundData.userId)
      .get();

    if (bookingsSnap.empty) {
      logger.error(`No booking found for refund ${event.params.refundId}`);
      await snapshot.ref.update({ status: "failed", error: "No booking found" });
      return;
    }

    // Sort in memory to get the most recent booking without needing a composite index
    const sortedDocs = bookingsSnap.docs.sort((a, b) => {
      const aTime = a.data().createdAt?.toMillis() || 0;
      const bTime = b.data().createdAt?.toMillis() || 0;
      return bTime - aTime;
    });

    const bookingDoc = sortedDocs[0];
    const bookingData = bookingDoc.data();
    const transactionId = bookingData.transactionId;

    // 2. Process Razorpay Refund
    if (transactionId && razorpay && refundData.refundAmount > 0) {
      const refundAmountPaise = Math.round(refundData.refundAmount * 100);
      
      await razorpay.payments.refund(transactionId, {
        amount: refundAmountPaise,
        speed: "normal",
        notes: { reason: "Attendee left event", refundId: event.params.refundId }
      });
    }

    // 3. Update the refund and booking documents
    await snapshot.ref.update({ status: "processed", processedAt: FieldValue.serverTimestamp() });
    await bookingDoc.ref.update({ status: "cancelled_by_attendee" });

    // 4. Send email to the attendee
    const userDoc = await db.collection("users").doc(refundData.userId).get();
    if (userDoc.exists && userDoc.data().email && transporter) {
      const attendeeName = userDoc.data().displayName || "there";
      const attendeeEmail = userDoc.data().email;
      
      const eventDoc = await db.collection("events").doc(refundData.eventId).get();
      const eventTitle = eventDoc.exists ? eventDoc.data().title : "the event";
      
      const refundBody = `
        <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello ${attendeeName},</h2>
        <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0 0 30px 0; white-space: pre-wrap;">You have successfully left "${eventTitle}".\n\nA partial refund of ₹${refundData.refundAmount} (after a 5% cancellation fee) has been initiated and will reflect in your original payment method in 5-7 business days.</p>
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

// ---------------------------------------------------------------------------
// Push Notifications (FCM)
// ---------------------------------------------------------------------------

/**
 * 14. sendPushOnNotification
 * Fires whenever a new in-app notification doc is created under
 * users/{uid}/notifications/{notifId} (i.e. every call to the client's
 * NotificationService.send()). Looks up that user's saved FCM token and
 * sends a push through Firebase Cloud Messaging so the notification also
 * shows up in the Android/iOS system tray, even if the app is closed.
 */
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
        },
        // Data payload lets the Flutter app route to the right screen on tap.
        // All values must be strings for FCM.
        data: {
          type: data.type || "",
          eventId: data.eventId || "",
          fromUid: data.fromUid || "",
          circleId: data.circleId || "",
          chatId: data.chatId || "",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
          },
        },
      });

      logger.info(`[Push] Sent to user ${uid}: ${response}`);
    } catch (err) {
      logger.error(`[Push] Failed to send push to user ${uid}:`, err);

      // Stale/uninstalled-app token — clean it up so future sends don't
      // keep failing on the same dead token.
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