const {
  onDocumentUpdated,
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

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

    // Detect kiosk emptied (high → low)
    const wasFull = before.fillLevel >= FILL_LEVEL_THRESHOLD;
    const nowLow = after.fillLevel <= 10;

    if (wasFull && nowLow) {
      console.log(`Kiosk ${kioskId} was emptied → Updating lastEmptied.`);
      await db.collection("kiosks").doc(kioskId).update({
        lastEmptied: FieldValue.serverTimestamp(),
      });
    }

    // Detect threshold crossing (low → high)
    const crossedThreshold =
      before.fillLevel < FILL_LEVEL_THRESHOLD &&
      after.fillLevel >= FILL_LEVEL_THRESHOLD;

    if (!crossedThreshold) return null;

    // Prevent duplicate pending tasks
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
//  FUNCTION 2: Award points + user recycling history
// ===============================================================
exports.awardPointsOnDeposit = onDocumentCreated(
  {
    document: "deposits/{depositId}",
    region: REGION,
  },
  async (event) => {
    if (!event.data) return null;

    const deposit = event.data.data();
    const userId = deposit.userId;
    const weightInGrams = deposit.weight;

    if (!userId || !weightInGrams) return null;

    const pointsToAward = Math.floor(weightInGrams / 10);
    const userRef = db.collection("users").doc(userId);

    // Update aggregates
    try {
      await userRef.update({
        points: FieldValue.increment(pointsToAward),
        totalRecycled: FieldValue.increment(weightInGrams),
        depositCount: FieldValue.increment(1),
        lastDepositAt: FieldValue.serverTimestamp(),
      });
      console.log(`Updated aggregates for user ${userId}`);
    } catch (err) {
      console.error("Error updating user aggregates:", err);
    }

    // Add history entry
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

      console.log(`Added recyclingHistory entry for user ${userId}`);
    } catch (err) {
      console.error("Error writing to recyclingHistory:", err);
    }

    return null;
  }
);

// ===============================================================
//  FUNCTION 3: Securely Create Admin
// ===============================================================
exports.createAdmin = onCall(async (request) => {
  const { email, password, name } = request.data;

  try {
    const userRecord = await getAuth().createUser({
      email,
      password,
      displayName: name,
    });

    await db.collection("users").doc(userRecord.uid).set({
      email,
      name,
      role: "admin",
      createdAt: FieldValue.serverTimestamp(),
      active: true,
    });

    return { success: true, message: "Admin created successfully." };
  } catch (error) {
    console.error("Error creating admin:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ===============================================================
//  FUNCTION 4: Securely Create Agent
// ===============================================================
exports.createAgent = onCall(async (request) => {
  const { email, password, name, phone, staffId, region } = request.data;

  try {
    const userRecord = await getAuth().createUser({
      email,
      password,
      displayName: name,
    });

    await db.collection("users").doc(userRecord.uid).set({
      email,
      name,
      role: "agent",
      phone: phone || "",
      staffId: staffId || "",
      region: region || "",
      createdAt: FieldValue.serverTimestamp(),
      active: true,
      tasksCompleted: 0,
    });

    return { success: true, message: "Agent created successfully." };
  } catch (error) {
    console.error("Error creating agent:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ===============================================================
//  FUNCTION 5: Securely Delete User
// ===============================================================
exports.deleteUser = onCall(async (request) => {
  const { targetUid } = request.data;

  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in.");
  }

  try {
    await getAuth().deleteUser(targetUid);
    await db.collection("users").doc(targetUid).delete();

    return { success: true, message: "User successfully deleted." };
  } catch (error) {
    console.error("Error deleting user:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ===============================================================
// FUNCTION 6: Auto-update kiosk + agent stats when task completed
// ===============================================================
exports.onCollectionTaskStatusChange = onDocumentUpdated(
  {
    document: "collectionTasks/{taskId}",
    region: REGION,
  },
  async (event) => {
    if (!event.data) return null;

    const before = event.data.before.data();
    const after = event.data.after.data();
    const taskId = event.params.taskId;

    // Only continue if status actually changed
    if (before.status === after.status) return null;

    // Only process when status becomes "completed"
    if (after.status !== "completed") return null;

    console.log(`Task ${taskId} marked completed.`);

    const kioskId = after.kioskId;
    const agentId = after.agentId;

    const batch = db.batch();
    const now = FieldValue.serverTimestamp();

    // -----------------------------
    // 1. Update KIOSK document
    // -----------------------------
    if (kioskId) {
      const kioskRef = db.collection("kiosks").doc(kioskId);
      batch.set(
        kioskRef,
        {
          fillLevel: 0,
          liquidHeight: 0,
          lastCollectedAt: now,
          lastUpdated: now,
        },
        { merge: true }
      );
    }

    // -----------------------------
    // 2. Update AGENT statistics
    // -----------------------------
    if (agentId) {
      const agentRef = db.collection("users").doc(agentId);
      batch.set(
        agentRef,
        {
          tasksCompleted: FieldValue.increment(1),
          lastTaskCompletedAt: now,
        },
        { merge: true }
      );
    }

    // -----------------------------
    // 3. Create a collection log entry
    // -----------------------------
    const logRef = db.collection("collectionLogs").doc();
    batch.set(logRef, {
      taskId,
      kioskId: kioskId || null,
      agentId: agentId || null,
      completedAt: now,
      fillLevelAtCreation: after.fillLevelAtCreation || null,
      proofPhotoUrl: after.proofPhotoUrl || null,
    });

    await batch.commit();
    console.log(`Post-processing for task ${taskId} completed.`);

    return null;
  }
);
