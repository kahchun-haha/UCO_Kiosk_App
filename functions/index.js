const {
  onDocumentUpdated,
  onDocumentCreated
} = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// ===========================================
// CONFIG
// ===========================================
const FILL_LEVEL_THRESHOLD = 80;
const REGION = "asia-southeast1";

// ===============================================================
//  FUNCTION 1: Auto-create collection task + update lastEmptied
// ===============================================================
exports.autoCreateCollectionTask = onDocumentUpdated(
  {
    document: "kiosks/{kioskId}",
    region: REGION,
  },
  async (event) => {
    if (!event.data) return null;

    const before = event.data.before.data();
    const after = event.data.after.data();
    const kioskId = event.params.kioskId;

    if (!before || !after) return null;

    console.log(
      `KIOSK UPDATE → ${kioskId} | Before: ${before.fillLevel}% | After: ${after.fillLevel}%`
    );

    // -------------------------------
    // Detect kiosk emptied event
    // -------------------------------
    const wasFull = before.fillLevel >= FILL_LEVEL_THRESHOLD;
    const nowLow = after.fillLevel <= 10;

    if (wasFull && nowLow) {
      console.log(`Kiosk ${kioskId} was emptied → Updating lastEmptied.`);
      await db.collection("kiosks").doc(kioskId).update({
        lastEmptied: FieldValue.serverTimestamp(),
      });
    }

    // -------------------------------
    // Detect threshold crossing (create collection task)
    // -------------------------------
    const crossedThreshold =
      before.fillLevel < FILL_LEVEL_THRESHOLD &&
      after.fillLevel >= FILL_LEVEL_THRESHOLD;

    if (!crossedThreshold) return null;

    // Check existing pending tasks
    const pendingTasks = await db
      .collection("collectionTasks")
      .where("kioskId", "==", kioskId)
      .where("status", "==", "pending")
      .get();

    if (!pendingTasks.empty) {
      console.log(`Kiosk ${kioskId} already has a pending task.`);
      return null;
    }

    console.log(`Creating NEW collection task for kiosk ${kioskId}.`);

    return db.collection("collectionTasks").add({
      kioskId,
      kioskName: after.name || "Unnamed Kiosk",
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      agentId: null,
      assignedAt: null,
      completedAt: null,
      fillLevelAtCreation: after.fillLevel,
    });
  }
);

// ===============================================================
//  FUNCTION 2: Award points + create user & kiosk history
// ===============================================================
exports.awardPointsOnDeposit = onDocumentCreated(
  {
    document: "deposits/{depositId}",
    region: REGION,
  },
  async (event) => {
    if (!event.data) {
      console.log("No deposit data found.");
      return null;
    }

    const deposit = event.data.data();
    const userId = deposit.userId;
    const weightInGrams = deposit.weight;

    if (!userId || !weightInGrams) {
      console.log("Deposit missing userId or weight.");
      return null;
    }

    // Your reward logic: 1 point per 10g
    const pointsToAward = Math.floor(weightInGrams / 10);

    console.log(
      `NEW DEPOSIT → user: ${userId} | weight: ${weightInGrams}g | points: ${pointsToAward}`
    );

    const userRef = db.collection("users").doc(userId);

    // ------------------------------------------------
    // Update user points + totalRecycled
    // ------------------------------------------------
    try {
      await userRef.update({
        points: FieldValue.increment(pointsToAward),
        totalRecycled: FieldValue.increment(weightInGrams),
        lastDepositAt: FieldValue.serverTimestamp(),
      });

      console.log(`Awarded ${pointsToAward} points to user ${userId}.`);
    } catch (err) {
      console.error(`Error updating user:`, err);
    }

    // ------------------------------------------------
    // Add to user recyclingHistory subcollection
    // ------------------------------------------------
    try {
      await db
        .collection("users")
        .doc(userId)
        .collection("recyclingHistory")
        .add({
          kioskId: deposit.kioskId || null,
          kioskName: deposit.kioskName || "Unknown",
          weight: weightInGrams,
          timestamp: FieldValue.serverTimestamp(),
        });

      console.log(`Added deposit to user recycling history.`);
    } catch (err) {
      console.error("Error writing to user recyclingHistory:", err);
    }

    // ------------------------------------------------
    // Add to kiosk deposit history
    // ------------------------------------------------
    try {
      if (deposit.kioskId) {
        await db
          .collection("kiosks")
          .doc(deposit.kioskId)
          .collection("deposits")
          .add({
            userId,
            weight: weightInGrams,
            timestamp: FieldValue.serverTimestamp(),
          });

        console.log(`Added deposit to kiosk deposit history.`);
      }
    } catch (err) {
      console.error("Error writing to kiosk deposits:", err);
    }

    return null;
  }
);
