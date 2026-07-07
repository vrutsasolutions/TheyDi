const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");
const Razorpay = require("razorpay");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

// Initialize Firebase Admin ONCE, at the top.
admin.initializeApp();
const db = admin.firestore();

// All functions live in this region so client base URLs stay consistent.
const REGION = "asia-south1";

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
      batch.update(userRef, {
        eventsAttended: FieldValue.increment(1),
      });

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
 * 4. createRazorpayXContact
 * Creates a RazorpayX Contact and Fund Account using provided bank details.
 */
exports.createRazorpayXContact = onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in.");

    const uid = request.auth.uid;
    const { name, ifsc, accountNumber } = request.data;

    if (!name || !ifsc || !accountNumber) {
      throw new HttpsError("invalid-argument", "Missing bank details.");
    }

    const userDoc = await db.collection("users").doc(uid).get();

    if (userDoc.exists && userDoc.data().razorpayXFundAccountId) {
      return { success: true, fundAccountId: userDoc.data().razorpayXFundAccountId, message: "Already onboarded." };
    }

    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_SECRET_KEY;
    if (!keyId || !keySecret) throw new HttpsError("internal", "Razorpay not configured.");
    const authHeader = "Basic " + Buffer.from(`${keyId}:${keySecret}`).toString("base64");

    try {
      // 1. Create Contact
      const contactRes = await fetch("https://api.razorpay.com/v1/contacts", {
        method: "POST",
        headers: { "Authorization": authHeader, "Content-Type": "application/json" },
        body: JSON.stringify({
          name: name,
          email: request.auth.token.email || "host@example.com",
          contact: "9999999999",
          type: "vendor",
          reference_id: uid,
        }),
      });
      const contact = await contactRes.json();
      if (!contact.id) throw new Error("Failed to create contact: " + JSON.stringify(contact));

      // 2. Create Fund Account
      const fundRes = await fetch("https://api.razorpay.com/v1/fund_accounts", {
        method: "POST",
        headers: { "Authorization": authHeader, "Content-Type": "application/json" },
        body: JSON.stringify({
          contact_id: contact.id,
          account_type: "bank_account",
          bank_account: {
            name: name,
            ifsc: ifsc,
            account_number: accountNumber,
          },
        }),
      });
      const fundAccount = await fundRes.json();
      if (!fundAccount.id) throw new Error("Failed to create fund account: " + JSON.stringify(fundAccount));

      // 3. Save to Firestore
      await db.collection("users").doc(uid).update({
        razorpayXContactId: contact.id,
        razorpayXFundAccountId: fundAccount.id,
      });

      return { success: true, fundAccountId: fundAccount.id };
    } catch (e) {
      logger.error("Error creating RazorpayX Contact/Fund Account", e);
      throw new HttpsError("internal", e.message || "Failed to create RazorpayX details");
    }
  }
);

/**
 * 5. releaseHostPayoutsX
 * Transfers the host's share of ticket revenue to their RazorpayX Fund Account.
 */
exports.releaseHostPayoutsX = onCall(
  { region: REGION },
  async (request) => {
    const { eventId, merchantAccountNumber } = request.data;
    if (!eventId) throw new HttpsError("invalid-argument", "Event ID required.");

    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) throw new HttpsError("not-found", "Event not found.");

    const hostUid = eventDoc.data().creatorUid;
    const hostDoc = await db.collection("users").doc(hostUid).get();
    const fundAccountId = hostDoc.data()?.razorpayXFundAccountId;

    if (!fundAccountId) throw new HttpsError("failed-precondition", "Host has no linked RazorpayX Fund Account.");

    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_SECRET_KEY;
    const authHeader = "Basic " + Buffer.from(`${keyId}:${keySecret}`).toString("base64");

    const bookings = await db.collection("bookings")
      .where("eventId", "==", eventId)
      .where("status", "==", "confirmed")
      .get();

    let transferCount = 0;
    const sourceAccount = merchantAccountNumber || process.env.RAZORPAYX_ACCOUNT_NUMBER;
    if (!sourceAccount) throw new HttpsError("invalid-argument", "Missing Merchant RazorpayX Account Number.");

    for (const doc of bookings.docs) {
      const bData = doc.data();
      if (bData.payoutStatus === "completed") continue;

      const payoutAmount = Math.floor((bData.totalAmount - (bData.platformFee || 0)) * 100);

      try {
        const payoutRes = await fetch("https://api.razorpay.com/v1/payouts", {
          method: "POST",
          headers: { "Authorization": authHeader, "Content-Type": "application/json" },
          body: JSON.stringify({
            account_number: sourceAccount,
            fund_account_id: fundAccountId,
            amount: payoutAmount,
            currency: "INR",
            mode: "IMPS",
            purpose: "payout",
            reference_id: `theydi_payout_${doc.id}`,
            notes: {
              project: "theydi",
              user_id: hostUid,
              bookingId: doc.id,
              eventId: eventId,
            },
          }),
        });
        const payoutData = await payoutRes.json();
        if (!payoutData.id) throw new Error("Payout failed: " + JSON.stringify(payoutData));

        await doc.ref.update({ payoutStatus: "completed" });
        transferCount++;
      } catch (e) {
        logger.error(`RazorpayX Payout failed for booking ${doc.id}`, e);
      }
    }

    return { success: true, transfersProcessed: transferCount };
  }
);

// ---------------------------------------------------------------------------
// Forgot Password Flow
// ---------------------------------------------------------------------------

const MAX_OTP_ATTEMPTS = 5;

/**
 * 6. sendOtp
 */
exports.sendOtp = onRequest({ cors: true, region: REGION }, async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ success: false, message: "Email is required" });
    const emailTrimmed = email.trim().toLowerCase();

    try {
      await admin.auth().getUserByEmail(emailTrimmed);
    } catch {
      return res.status(404).json({ success: false, message: "No account found with this email" });
    }

    const transporter = getTransporter();
    if (!transporter) {
      return res.status(500).json({ success: false, message: "Email service is not configured." });
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

    await transporter.sendMail({
      from: `"Your App" <${process.env.GMAIL_USER}>`,
      to: emailTrimmed,
      subject: "Password Reset OTP",
      text: `Your OTP is ${otp}. Valid for 10 mins.`,
      html: `<p>Your OTP is <strong>${otp}</strong>. Valid for 10 mins.</p>`,
    });

    return res.status(200).json({ success: true, message: "OTP sent" });
  } catch (error) {
    logger.error("Error sending OTP", error);
    return res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * 7. verifyOtp
 */
exports.verifyOtp = onRequest({ cors: true, region: REGION }, async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) return res.status(400).json({ success: false, message: "Missing fields" });

    const emailTrimmed = email.trim().toLowerCase();
    const docRef = db.collection("password_reset_otps").doc(emailTrimmed);
    const doc = await docRef.get();
    if (!doc.exists) return res.status(400).json({ success: false, message: "No active OTP request" });

    const data = doc.data();
    if (data.expiresAt.toDate() < new Date()) {
      return res.status(400).json({ success: false, message: "OTP expired" });
    }

    if ((data.attempts || 0) >= MAX_OTP_ATTEMPTS) {
      return res.status(429).json({ success: false, message: "Too many attempts. Please request a new OTP." });
    }

    if (data.otp !== otp.trim()) {
      await docRef.update({ attempts: FieldValue.increment(1) });
      return res.status(400).json({ success: false, message: "Invalid OTP" });
    }

    const verifiedExpiresAt = new Date(Date.now() + 5 * 60 * 1000);
    await docRef.update({ verified: true, verifiedExpiresAt });

    return res.status(200).json({ success: true, message: "OTP verified" });
  } catch (error) {
    logger.error("Error verifying OTP", error);
    return res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * 8. resetPassword
 */
exports.resetPassword = onRequest({ cors: true, region: REGION }, async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ success: false, message: "Missing fields" });

    const emailTrimmed = email.trim().toLowerCase();
    const docRef = db.collection("password_reset_otps").doc(emailTrimmed);
    const doc = await docRef.get();
    if (!doc.exists) return res.status(400).json({ success: false, message: "Session not found" });

    const data = doc.data();
    if (!data.verified || data.verifiedExpiresAt.toDate() < new Date()) {
      await db.collection("password_reset_logs").add({
        email: emailTrimmed,
        resetAt: FieldValue.serverTimestamp(),
        success: false,
        reason: "Verification expired or invalid",
      });
      return res.status(400).json({ success: false, message: "Verification expired or invalid" });
    }

    const user = await admin.auth().getUserByEmail(emailTrimmed);
    await admin.auth().updateUser(user.uid, { password });

    // Keep a permanent, non-sensitive audit record that a reset happened —
    // this never stores the OTP itself, only proof that a reset occurred.
    await db.collection("password_reset_logs").add({
      email: emailTrimmed,
      resetAt: FieldValue.serverTimestamp(),
      success: true,
    });

    await docRef.delete();

    return res.status(200).json({ success: true, message: "Password updated" });
  } catch (error) {
    logger.error("Error resetting password", error);
    return res.status(500).json({ success: false, message: error.message });
  }
});