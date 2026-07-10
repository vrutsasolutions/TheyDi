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
      } else if (event.event === "payout.processed") {
        const payout = event.payload.payout.entity;
        const notes = payout.notes || {};
        const { eventId, bookingId } = notes;

        if (eventId && bookingId) {
          logger.info(`[Webhook] Payout processed successfully for event ${eventId}, booking ${bookingId}`);
          await db.collection("events").doc(eventId).collection("attendeePayments").doc(bookingId).update({
            payoutStatus: "completed",
            payoutCompletedAt: FieldValue.serverTimestamp()
          });
        }
      } else if (event.event === "payout.failed" || event.event === "payout.reversed" || event.event === "payout.rejected") {
        const payout = event.payload.payout.entity;
        const notes = payout.notes || {};
        const { eventId, bookingId } = notes;

        if (eventId && bookingId) {
          logger.warn(`[Webhook] Payout failed/reversed for event ${eventId}, booking ${bookingId}`);
          await db.collection("events").doc(eventId).collection("attendeePayments").doc(bookingId).update({
            payoutStatus: "failed",
            payoutFailedAt: FieldValue.serverTimestamp(),
            payoutFailureReason: payout.failure_reason || "Unknown reason"
          });

          // Send Email & Notification to Host
          const hostUid = notes.user_id;
          if (hostUid) {
            try {
              const hostDoc = await db.collection("users").doc(hostUid).get();
              const hostData = hostDoc.data();
              if (hostData) {
                // 1. Send Email
                if (hostData.email) {
                  const transporter = getTransporter();
                  if (transporter) {
                    const emailBody = `
                      <h2 style="color: #000000; font-size: 20px; font-weight: 600; margin: 0 0 16px 0;">Hello ${hostData.displayName || 'Host'},</h2>
                      <h3 style="color: #10B981; font-size: 18px; margin: 0 0 10px 0;">Action Required: Payout Failed ⚠️</h3>
                      <p style="color: #4B5563; font-size: 15px; line-height: 24px; margin: 0;">
                        Unfortunately, your payout for a booking in your event failed.<br><br>
                        <strong>Reason from bank:</strong> ${payout.failure_reason || 'Incorrect bank details'}.<br><br>
                        Please update your bank details in the TheyDi app as soon as possible so we can safely retry your payment.
                      </p>
                    `;
                    const html = getBaseEmailHtml("Action Required: Payout Failed", emailBody);

                    await transporter.sendMail({
                      from: `"TheyDi Team" <${process.env.GMAIL_USER}>`,
                      to: hostData.email,
                      subject: "Action Required: Payout Failed ⚠️",
                      text: `Hi ${hostData.displayName || 'Host'},\n\nUnfortunately, your payout for a booking in your event failed. \n\nReason from bank: ${payout.failure_reason || 'Incorrect bank details'}.\n\nPlease update your bank details in the TheyDi app as soon as possible so we can safely retry your payment.\n\nThank you,\nTheyDi Team`,
                      html: html
                    });
                  }
                }
                
                // 2. In-App Notification
                await db.collection("notifications").add({
                  toUid: hostUid,
                  title: "Payout Failed ⚠️",
                  body: `Your bank rejected a payout. Reason: ${payout.failure_reason || 'Incorrect bank details'}. Please update your account details.`,
                  type: "payout_failed",
                  eventId: eventId,
                  createdAt: FieldValue.serverTimestamp(),
                  isRead: false
                });
              }
            } catch (notifyErr) {
              logger.error("[Webhook] Failed to send failure notification to host:", notifyErr);
            }
          }
        }
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
    const { payoutMethod, upiId, name, ifsc, accountNumber } = request.data;
    const mode = payoutMethod === 'upi' ? 'vpa' : 'bank_account';
    
    if (mode === 'vpa') {
      if (!upiId) throw new HttpsError("invalid-argument", "Missing UPI ID.");
    } else {
      if (!name || !ifsc || !accountNumber) throw new HttpsError("invalid-argument", "Missing bank details.");
    }

    const userDoc = await db.collection("users").doc(uid).get();
    
    let contactId = null;
    if (userDoc.exists) {
      contactId = userDoc.data().razorpayXContactId;
    }

    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_SECRET_KEY;
    if (!keyId || !keySecret) throw new HttpsError("internal", "Razorpay not configured.");
    const authHeader = "Basic " + Buffer.from(`${keyId}:${keySecret}`).toString("base64");

    try {
      if (!contactId) {
        logger.info(`[RazorpayX] Attempting to create contact for UID: ${uid} with name: ${name || "Host"}`);
        // 1. Create Contact
        const contactRes = await fetch("https://api.razorpay.com/v1/contacts", {
          method: "POST",
          headers: { "Authorization": authHeader, "Content-Type": "application/json" },
          body: JSON.stringify({
            name: name || "Host",
            email: request.auth.token.email || "host@example.com",
            type: "vendor",
            reference_id: uid,
          })
        });
        const contact = await contactRes.json();
        logger.info(`[RazorpayX] Contact API Response: ${JSON.stringify(contact)}`);
        
        if (!contact.id) throw new Error("Failed to create contact: " + JSON.stringify(contact));
        contactId = contact.id;
      }

      logger.info(`[RazorpayX] Attempting to create fund account for Contact ID: ${contactId}`);
      // 2. Create Fund Account
      const fundAccountPayload = {
        contact_id: contactId,
        account_type: mode,
      };
      if (mode === 'vpa') {
        fundAccountPayload.vpa = { address: upiId };
      } else {
        fundAccountPayload.bank_account = {
          name: name,
          ifsc: ifsc,
          account_number: accountNumber
        };
      }

      const fundRes = await fetch("https://api.razorpay.com/v1/fund_accounts", {
        method: "POST",
        headers: { "Authorization": authHeader, "Content-Type": "application/json" },
        body: JSON.stringify(fundAccountPayload)
      });
      const fundAccount = await fundRes.json();
      logger.info(`[RazorpayX] Fund Account API Response: ${JSON.stringify(fundAccount)}`);
      
      if (!fundAccount.id) throw new Error("Failed to create fund account: " + JSON.stringify(fundAccount));

      // 3. Save to Firestore
      logger.info(`[RazorpayX] Saving RazorpayX IDs to Firestore for UID: ${uid}`);
      await db.collection("users").doc(uid).update({ 
        razorpayXContactId: contactId,
        razorpayXFundAccountId: fundAccount.id,
        razorpayXPayoutMode: mode === 'vpa' ? 'UPI' : 'IMPS'
      });

      logger.info(`[RazorpayX] Successfully onboarded UID: ${uid}`);
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
async function processPayoutForEventId(eventId, merchantAccountNumber) {
  if (!eventId) throw new HttpsError("invalid-argument", "Event ID required.");
    
  const db = admin.firestore();
  logger.info(`[HostPayout] Starting payout process for event: ${eventId}`);
  
  const eventDoc = await db.collection("events").doc(eventId).get();
  if (!eventDoc.exists) throw new HttpsError("not-found", "Event not found.");

  const eventData = eventDoc.data();
  if (eventData.payoutProcessed) {
    logger.info(`[HostPayout] Event ${eventId} has already been processed for payouts.`);
    return { success: true, transfersProcessed: 0, message: "Payout already processed." };
  }

  const hostUid = eventData.creatorUid;
  logger.info(`[HostPayout] Event host UID: ${hostUid}`);
  
  const hostDoc = await db.collection("users").doc(hostUid).get();
  const hostData = hostDoc.data() || {};
  const fundAccountId = hostData.razorpayXFundAccountId;
  const payoutMode = hostData.razorpayXPayoutMode || "IMPS";

  if (!fundAccountId) throw new HttpsError("failed-precondition", "Host has no linked RazorpayX Fund Account.");
  logger.info(`[HostPayout] Found host fund account: ${fundAccountId} with mode ${payoutMode}`);

  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_SECRET_KEY;
  const authHeader = "Basic " + Buffer.from(`${keyId}:${keySecret}`).toString("base64");

  const bookings = await db.collection("bookings").where("eventId", "==", eventId).where("status", "==", "confirmed").get();
  logger.info(`[HostPayout] Found ${bookings.docs.length} confirmed bookings for this event.`);
  
  const attendeeUids = eventDoc.data().attendeeUids || [];
  
  let transferCount = 0;
  const sourceAccount = merchantAccountNumber || process.env.RAZORPAYX_ACCOUNT_NUMBER;
  if (!sourceAccount) throw new HttpsError("invalid-argument", "Missing Merchant RazorpayX Account Number.");
  logger.info(`[HostPayout] Using source account: ${sourceAccount}`);
  
  for (const doc of bookings.docs) {
    const bData = doc.data();
    logger.info(`[HostPayout] Processing booking ID: ${doc.id} - payoutStatus: ${bData.payoutStatus}`);
    if (bData.payoutStatus === "completed") continue;
    
    // Double check that the user is actually still in the event's attendee list!
    // This protects against manual database deletions where the booking was left behind.
    if (!attendeeUids.includes(bData.userId)) {
      logger.info(`[HostPayout] Skipping booking ${doc.id} because user ${bData.userId} is no longer in the event attendee list.`);
      continue;
    }

    const baseAmount = bData.amount !== undefined ? bData.amount : (bData.totalAmount - (bData.platformFee || 0));
    const hostFee = bData.platformFee || 0; // Deduct same platform fee amount (5%) from host
    const payoutAmount = Math.floor((baseAmount - hostFee) * 100);
    logger.info(`[HostPayout] Calculated payout amount (in paise): ${payoutAmount} for booking ${doc.id}`);

    try {
      logger.info(`[HostPayout] Sending ${payoutMode} payout request for booking ${doc.id} to Razorpay...`);
      const payoutRes = await fetch("https://api.razorpay.com/v1/payouts", {
        method: "POST",
        headers: { "Authorization": authHeader, "Content-Type": "application/json" },
        body: JSON.stringify({
          account_number: sourceAccount,
          fund_account_id: fundAccountId,
          amount: payoutAmount,
          currency: "INR",
          mode: payoutMode,
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
      logger.info(`[HostPayout] Razorpay response for booking ${doc.id}: ${JSON.stringify(payoutData)}`);
      
      if (!payoutData.id) throw new Error("Payout failed: " + JSON.stringify(payoutData));

      await doc.ref.update({ 
        payoutStatus: "processing", 
        payoutId: payoutData.id 
      });
      transferCount++;
      logger.info(`[HostPayout] Successfully queued payout for booking ${doc.id}`);
    } catch (e) {
      logger.error(`RazorpayX Payout failed for booking ${doc.id}`, e);
    }
  }

  // Mark the event itself as completed and payoutProcessed
  logger.info(`[HostPayout] Marking event ${eventId} as completed and payout processed.`);
  await eventDoc.ref.update({ status: "completed", payoutProcessed: true });

  // ── Email Notifications for Event Completion ──
  try {
    const transporter = getTransporter();
    if (transporter) {
      const eventTitle = eventDoc.data().title || "Your Event";
      const hostName = eventDoc.data().creatorName || "The Host";

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
          title: '✅ Event completed',
          body: `"${eventTitle}" is now marked as completed.`,
          type: 'system',
          eventId: eventId,
          createdAt: FieldValue.serverTimestamp(),
          isRead: false
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
            title: 'Event ended',
            body: `Hope you enjoyed "${eventTitle}"!`,
            type: 'system',
            eventId: eventId,
            createdAt: FieldValue.serverTimestamp(),
            isRead: false
          });
        }
      }
    }
  } catch (err) {
    logger.error("[HostPayout] Error sending completion emails:", err);
  }

  return { success: true, transfersProcessed: transferCount };
}

exports.releaseHostPayoutsX = onCall(
  { region: REGION },
  async (request) => {
    return await processPayoutForEventId(request.data.eventId, request.data.merchantAccountNumber);
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
        await processPayoutForEventId(doc.id, null);
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
