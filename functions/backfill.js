#!/usr/bin/env node
/**
 * backfill.js — One-time script to create missing Firestore user profiles.
 *
 * Run from the functions/ folder:
 *
 *   cd functions
 *   node backfill.js
 *
 * Requires: GOOGLE_APPLICATION_CREDENTIALS env var pointing to a service-
 * account key, OR being run on a machine already authenticated via
 * `firebase login` + `gcloud auth application-default login`.
 *
 * Simplest approach: download a service-account key from
 *   Firebase Console → Project Settings → Service Accounts → Generate New Private Key
 * then run:
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\key.json
 *   node backfill.js
 */

const admin = require("firebase-admin");

// Initialize — uses GOOGLE_APPLICATION_CREDENTIALS or default credentials
admin.initializeApp();

const db = admin.firestore();

async function backfill() {
  let nextPageToken;
  let fixed = 0;
  let skipped = 0;
  let total = 0;

  console.log("Starting backfill of missing Firestore user profiles...\n");

  do {
    const listResult = await admin.auth().listUsers(1000, nextPageToken);

    for (const user of listResult.users) {
      total++;

      try {
        const docRef = db.collection("users").doc(user.uid);
        const snap = await docRef.get();

        if (snap.exists) {
          skipped++;
          continue;
        }

        // Document does NOT exist — create it
        await docRef.set({
          uid:          user.uid,
          name:         user.displayName || "User",
          displayName:  user.displayName || "User",
          email:        user.email || "",
          phone:        user.phoneNumber || "",
          createdAt:    admin.firestore.FieldValue.serverTimestamp(),
          eventsJoined: [],
          eventsHosted: [],
          city:         "",
          bio:          "",
          photoUrl:     user.photoURL || "",
          age:          null,
          gender:       "",
          interests:    [],
          isVerified:   false,
        });

        fixed++;
        console.log(`  ✅ CREATED profile for ${user.uid} (${user.email || "no-email"})`);
      } catch (err) {
        console.error(`  ❌ FAILED for ${user.uid}: ${err.message}`);
      }
    }

    nextPageToken = listResult.pageToken;
  } while (nextPageToken);

  console.log(`\n════════════════════════════════════════`);
  console.log(`  Total Auth users:    ${total}`);
  console.log(`  Already had profile: ${skipped}`);
  console.log(`  Fixed (created):     ${fixed}`);
  console.log(`════════════════════════════════════════\n`);
}

backfill()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Fatal error:", err);
    process.exit(1);
  });