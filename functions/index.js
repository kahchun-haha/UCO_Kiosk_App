const {
  onDocumentUpdated,
  onDocumentCreated
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
    // FIXED: Used 'collection_tasks' to match your Firestore Screenshot
    const pendingTasks = await db
      .collection("collection_tasks") 
      .where("kioskId", "==", kioskId)
      .where("status", "==", "pending")
      .get();

    if (!pendingTasks.empty) {
      console.log(`Kiosk ${kioskId} already has a pending task.`);
      return null;
    }

    console.log(`Creating NEW collection task for kiosk ${kioskId}.`);

    // FIXED: Used 'collection_tasks' to match your Firestore Screenshot
    return db.collection("collection_tasks").add({
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
    if (!event.data) return null;

    const deposit = event.data.data();
    const userId = deposit.userId;
    const weightInGrams = deposit.weight;

    if (!userId || !weightInGrams) return null;

    // Logic: 1 point per 10g
    const pointsToAward = Math.floor(weightInGrams / 10);
    const userRef = db.collection("users").doc(userId);

    // ------------------------------------------------
    // 1. UPDATE USER AGGREGATES (The Professional Fix)
    // ------------------------------------------------
    try {
      await userRef.update({
        points: FieldValue.increment(pointsToAward),
        
        // Matches 'totalRecycled' in your DB. We divide by 1000 in frontend to get Liters/Kg.
        totalRecycled: FieldValue.increment(weightInGrams), 
        
        // NEW: Explicitly count the deposit
        depositCount: FieldValue.increment(1), 
        
        lastDepositAt: FieldValue.serverTimestamp(),
      });
      console.log(`Updated aggregates for user ${userId}`);
    } catch (err) {
      console.error(`Error updating user:`, err);
    }

    // ------------------------------------------------
    // 2. Add to user recyclingHistory subcollection
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
    } catch (err) {
      console.error("Error writing to user recyclingHistory:", err);
    }

    // ------------------------------------------------
    // 3. Add to kiosk deposit history
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
      }
    } catch (err) {
      console.error("Error writing to kiosk deposits:", err);
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
    // 1. Create user in Firebase Auth
    const userRecord = await getAuth().createUser({
      email,
      password,
      displayName: name,
    });

    // 2. Create user profile in Firestore
    await db.collection("users").doc(userRecord.uid).set({
      email,
      name,
      role: "admin",
      createdAt: FieldValue.serverTimestamp(),
      active: true
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
  // Agents have extra fields like phone, staffId, region
  const { email, password, name, phone, staffId, region } = request.data;

  try {
    // 1. Create user in Firebase Auth
    const userRecord = await getAuth().createUser({
      email,
      password,
      displayName: name,
    });

    // 2. Create user profile in Firestore with AGENT specific fields
    await db.collection("users").doc(userRecord.uid).set({
      email,
      name,
      role: "agent",
      phone: phone || "",
      staffId: staffId || "",
      region: region || "",
      createdAt: FieldValue.serverTimestamp(),
      active: true,
      // Initialize agent stats
      tasksCompleted: 0 
    });

    return { success: true, message: "Agent created successfully." };
  } catch (error) {
    console.error("Error creating agent:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ===============================================================
//  FUNCTION 5: Securely Delete User (Super Admin Only)
// ===============================================================
exports.deleteUser = onCall(async (request) => {
  const { targetUid } = request.data;

  // Security Check: Ensure the caller is logged in
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in.");
  }

  try {
    // 1. Remove from Firebase Authentication (Prevent login)
    await getAuth().deleteUser(targetUid);

    // 2. Remove from Firestore (Clean up data)
    await db.collection("users").doc(targetUid).delete();

    return { success: true, message: "User successfully deleted." };
  } catch (error) {
    console.error("Error deleting user:", error);
    throw new HttpsError("internal", error.message);
  }
});