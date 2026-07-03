const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const Razorpay = require("razorpay");
const crypto = require("crypto");

admin.initializeApp();

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

/**
 * 1. createOrder
 * Called from Flutter to create a Razorpay Order ID securely.
 */
exports.createOrder = onCall(
  { region: "asia-south1" },
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
});

/**
 * 2. verifyPayment
 * Called from Flutter after Razorpay UI succeeds.
 * Verifies the signature and writes the booking to Firestore.
 */
exports.verifyPayment = onCall(
  { region: "asia-south1" },
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
    const db = admin.firestore();
    
    // BUG FIX: Check if webhook already processed this payment
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Run as a batch write for atomicity
    const batch = db.batch();

    // 1. Create Booking record
    const newBookingRef = db.collection("bookings").doc();
    batch.set(newBookingRef, bookingData);

    // 2. Add user to attendees array in event
    const eventRef = db.collection("events").doc(eventId);
    const eventUpdates = {
      attendeeUids: admin.firestore.FieldValue.arrayUnion(uid),
    };
    if (fromApproval) {
      eventUpdates.approvedPendingPaymentUids = admin.firestore.FieldValue.arrayRemove(uid);
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
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      eventId,
    }, { merge: true });

    // 4. Update user event count
    const userRef = db.collection("users").doc(uid);
    batch.update(userRef, {
      eventsAttended: admin.firestore.FieldValue.increment(1)
    });

    // 5. Create Payment history record in root 'payment' collection
    const globalPaymentRef = db.collection("payment").doc(razorpay_payment_id);
    batch.set(globalPaymentRef, {
      amount: amount || totalAmount || 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      currency: "INR",
      eventId: eventId,
      orderId: razorpay_order_id,
      paymentId: razorpay_payment_id,
      paymentMethod: paymentMethod || "Unknown",
      status: "Success",
      uid: uid,
      username: userName,
      verified: true
    });

    await batch.commit();

    return { success: true, message: "Payment verified and booking confirmed." };
  } catch (error) {
    logger.error("Failed to process booking after payment validation", error);
    throw new HttpsError("internal", "Payment was verified but failed to write booking to database.");
  }
});

/**
 * 3. razorpayWebhook
 * Called by Razorpay when an event (e.g., order.paid) occurs.
 * This acts as a reliable fallback in case the client app crashes or loses internet.
 */
exports.razorpayWebhook = onRequest(
  { region: "asia-south1" },
  async (req, res) => {
  // Webhook secret should be configured in your environment variables or Razorpay dashboard.
  // For demonstration, we'll try to use a secret from process.env if available.
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

      const db = admin.firestore();
      
      // Check if booking already exists (from client-side verifyPayment)
      const existingPaymentRef = await db.collection("events").doc(notes.eventId)
                                         .collection("attendeePayments").doc(notes.userId).get();
      
      if (existingPaymentRef.exists && existingPaymentRef.data().status === "paid") {
        logger.info("Payment already processed by client");
        return res.status(200).send("Already processed");
      }

      logger.info("Processing webhook for order.paid", { orderId: order.id, userId: notes.userId });

      // Prepare Booking Data based on notes
      const bookingData = {
        eventId: notes.eventId,
        eventTitle: notes.eventTitle || "Unknown Event",
        userId: notes.userId,
        userName: "User", // Can't easily get full name here
        hostUid: notes.hostUid,
        amount: order.amount / 100,
        platformFee: parseFloat(notes.platformFee || "0"),
        totalAmount: parseFloat(notes.totalAmount || "0"),
        status: "confirmed",
        paymentMethod: payment.method || "Unknown",
        transactionId: payment.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const batch = db.batch();
      
      // 1. Create Booking record
      const newBookingRef = db.collection("bookings").doc();
      batch.set(newBookingRef, bookingData);

      // 2. Add user to attendees array in event
      const eventRef = db.collection("events").doc(notes.eventId);
      const eventUpdates = {
        attendeeUids: admin.firestore.FieldValue.arrayUnion(notes.userId),
      };
      if (notes.fromApproval === "true") {
        eventUpdates.approvedPendingPaymentUids = admin.firestore.FieldValue.arrayRemove(notes.userId);
      }
      batch.update(eventRef, eventUpdates);

      // 3. Mark attendeePayments as paid
      const paymentRef = eventRef.collection("attendeePayments").doc(notes.userId);
      batch.set(paymentRef, {
        status: "paid",
        userName: "User",
        transactionId: payment.id,
        paymentMethod: payment.method || "Unknown",
        amount: bookingData.totalAmount,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        eventId: notes.eventId,
      }, { merge: true });

      // 4. Update user event count
      const userRef = db.collection("users").doc(notes.userId);
      batch.update(userRef, {
        eventsAttended: admin.firestore.FieldValue.increment(1)
      });

      // 5. Create Payment history record in root 'payment' collection
      const globalPaymentRef = db.collection("payment").doc(payment.id);
      batch.set(globalPaymentRef, {
        amount: bookingData.totalAmount,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        currency: "INR",
        eventId: notes.eventId,
        orderId: order.id,
        paymentId: payment.id,
        paymentMethod: payment.method || "Unknown",
        status: "Success",
        uid: notes.userId,
        username: "User", // We don't have the full name in webhook easily
        verified: true
      });

      await batch.commit();
      logger.info("Webhook processed payment successfully", { orderId: order.id });
    }

    return res.status(200).send("OK");
  } catch (error) {
    logger.error("Error processing webhook", error);
    return res.status(500).send("Internal Server Error");
  }
});
