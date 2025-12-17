// functions/index.js
const sgMail = require("@sendgrid/mail");
const { defineSecret } = require("firebase-functions/params");

// SendGrid secret (stored in Firebase secrets manager)
const SENDGRID_API_KEY = defineSecret("SENDGRID_API_KEY");

// Change this to your verified SendGrid sender
const EMAIL_FROM = "transitmalaya@gmail.com";

const {
  onDocumentUpdated,
  onDocumentCreated,
  onDocumentDeleted,
} = require("firebase-functions/v2/firestore");

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const crypto = require("crypto");
const { onSchedule } = require("firebase-functions/v2/scheduler");

initializeApp();
const db = getFirestore();

// ===========================================
// CONFIG
// ===========================================
const FILL_LEVEL_THRESHOLD = 80;
const REGION = "asia-southeast1";

// ✅ Zones for agent assignment (must match your React dropdown)
const ALLOWED_ZONES = ["Zone A", "Zone B", "Zone C"];

// ===========================================
// HELPERS
// ===========================================
async function getCallerRole(request) {
  if (!request.auth?.uid) return null;

  const meRef = db.collection("users").doc(request.auth.uid);
  const meSnap = await meRef.get();
  if (!meSnap.exists) return null;

  return meSnap.data()?.role ?? null;
}

async function assertAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login required.");
  }
  const role = await getCallerRole(request);
  if (role !== "admin" && role !== "superadmin") {
    throw new HttpsError("permission-denied", "Admins only.");
  }
}

// ✅ NEW: kiosk-only callable protection (or allow admin/superadmin for testing)
async function assertKiosk(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login required.");
  }
  const role = await getCallerRole(request);
  if (role !== "kiosk" && role !== "admin" && role !== "superadmin") {
    throw new HttpsError("permission-denied", "Kiosk only.");
  }
}

function assertZone(zone) {
  if (!zone || !ALLOWED_ZONES.includes(zone)) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid zone. Allowed: ${ALLOWED_ZONES.join(", ")}`
    );
  }
}

/**
 * Generate sequential agent code like: AGT-000001
 * Requires Firestore doc: counters/agents { next: 1 }
 */
async function generateAgentId() {
  const counterRef = db.collection("counters").doc("agents");

  return await db.runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const rawNext = snap.exists ? snap.data()?.next : 1;
    const next = Number.isFinite(rawNext) ? rawNext : 1;

    tx.set(counterRef, { next: next + 1 }, { merge: true });

    return `AGT-${String(next).padStart(3, "0")}`; // AGT-001
  });
}


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
    const wasFull = (before.fillLevel ?? 0) >= FILL_LEVEL_THRESHOLD;
    const nowLow = (after.fillLevel ?? 0) <= 10;

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
      (before.fillLevel ?? 0) < FILL_LEVEL_THRESHOLD &&
      (after.fillLevel ?? 0) >= FILL_LEVEL_THRESHOLD;

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
      kioskName: after.name || after.location || "Unnamed Kiosk",
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      agentUid: null,
      agentId: null,
      assignedAt: null,
      startedAt: null,
      completedAt: null,

      fillLevelAtCreation: after.fillLevel ?? 0,

      proofPhotoUrl: null,
      proofUploadedAt: null,

      // used by Function 6 to prevent double processing
      postProcessedAt: null,
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
      await userRef.set(
        {
          points: FieldValue.increment(pointsToAward),
          totalRecycled: FieldValue.increment(weightInGrams),
          depositCount: FieldValue.increment(1),
          lastDepositAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
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
//  FUNCTION 3: Securely Create Admin (admin-only)
// ===============================================================
exports.createAdmin = onCall({ region: REGION }, async (request) => {
  await assertAdmin(request);

  const { email, password, name } = request.data || {};
  if (!email || !password || !name) {
    throw new HttpsError("invalid-argument", "Missing email/password/name.");
  }

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
//  FUNCTION 4: Securely Create Agent (admin-only) + AUTO agentCode
// ===============================================================
exports.createAgent = onCall({ region: REGION }, async (request) => {
  await assertAdmin(request);

  const { email, password, name, phone, region } = request.data || {};
  if (!email || !password || !name) {
    throw new HttpsError("invalid-argument", "Missing email/password/name.");
  }

  // ✅ Validate zone coming from your dropdown
  assertZone(region);

  try {
    const agentId = await generateAgentId();

    const userRecord = await getAuth().createUser({
      email,
      password,
      displayName: name,
    });

    await db.collection("users").doc(userRecord.uid).set({
      email,
      name,
      role: "agent",
      agentId, // ✅ auto ID
      phone: phone || "",
      region, // ✅ stored as zone
      createdAt: FieldValue.serverTimestamp(),
      active: true,
      tasksCompleted: 0,
      lastTaskCompletedAt: null,
      pushNotifications: true,
      emailUpdates: false,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { success: true, agentId, message: "Agent created successfully." };
  } catch (error) {
    console.error("Error creating agent:", error);
      throw new HttpsError(
    "internal",
    "createAgent failed",
    {
      originalMessage: error?.message || null,
      originalCode: error?.code || null,
      stack: error?.stack || null,
    }
  ); 
  }
});

// ===============================================================
//  FUNCTION 5: Securely Delete User (admin-only)
// ===============================================================
exports.deleteUser  = onCall({ region: REGION }, async (request) => {
  await assertAdmin(request);

  const { targetUid } = request.data || {};
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "Missing targetUid.");
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
//  FUNCTION 6 (BEST PRACTICE):
//  When a task becomes COMPLETED, server performs all side effects.
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

    if (!before || !after) return null;

    // Only when status actually changes
    if (before.status === after.status) return null;

    // Only when it becomes completed
    if (after.status !== "completed") return null;

    // Prevent double processing
    if (after.postProcessedAt) {
      console.log(`Task ${taskId} already post-processed. Skipping.`);
      return null;
    }

    const kioskId = after.kioskId;
    const agentUid = after.agentUid;   // ✅ Firebase UID
    const agentId = after.agentId;     // optional, for logging only

    console.log(`Task ${taskId} marked completed. Post-processing...`);

    const batch = db.batch();
    const now = FieldValue.serverTimestamp();

    // 0) Mark task post-processed
    const taskRef = db.collection("collectionTasks").doc(taskId);
    batch.set(
      taskRef,
      {
        postProcessedAt: now,
        completedAt: after.completedAt || now,
      },
      { merge: true }
    );

    // 1) Update KIOSK
    if (kioskId) {
      const kioskRef = db.collection("kiosks").doc(kioskId);
      batch.set(
        kioskRef,
        {
          fillLevel: 0,
          liquidHeight: 0,
          lastCollected: now,
          lastEmptied: now,
          lastUpdated: now,
          assignedAgentUid: agentUid || null,
          assignedAgentId: agentId || null,
        },
        { merge: true }
      );
    }

    // 2) Update AGENT statistics
    if (agentUid) {
      const agentRef = db.collection("users").doc(agentUid);
      batch.set(
        agentRef,
        {
          tasksCompleted: FieldValue.increment(1),
          lastTaskCompletedAt: now,
        },
        { merge: true }
      );
    }

    // 3) Create collection log entry
    const logRef = db.collection("collectionLogs").doc();
    batch.set(logRef, {
      taskId,
      kioskId: kioskId || null,
      agentId: agentId || null,
      completedAt: now,
      fillLevelAtCreation: after.fillLevelAtCreation || null,
      proofPhotoUrl: after.proofPhotoUrl || null,
      createdAt: now,
    });

    await batch.commit();
    console.log(`Post-processing for task ${taskId} completed.`);
    return null;
  }
);

// ===============================================================
//  FUNCTION 7: Keep aggregates correct when a deposit is DELETED
// ===============================================================
exports.onDepositDeleted = onDocumentDeleted(
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

    const pointsToRemove = Math.floor(weightInGrams / 10);

    await db
      .collection("users")
      .doc(userId)
      .set(
        {
          points: FieldValue.increment(-pointsToRemove),
          totalRecycled: FieldValue.increment(-weightInGrams),
          depositCount: FieldValue.increment(-1),
        },
        { merge: true }
      );

    return null;
  }
);

// ===============================================================
//  FUNCTION 8: One-time rebuild aggregates (fix mismatch)
// ===============================================================
exports.rebuildUserAggregates = onCall({ region: REGION }, async (request) => {
  await assertAdmin(request);

  const snap = await db.collection("deposits").get();

  const perUser = new Map(); // userId -> { grams, count, points }
  snap.forEach((doc) => {
    const d = doc.data();
    const userId = d.userId;
    const weight = d.weight || 0;
    if (!userId || !weight) return;

    const points = Math.floor(weight / 10);

    const cur = perUser.get(userId) || { grams: 0, count: 0, points: 0 };
    cur.grams += weight;
    cur.count += 1;
    cur.points += points;
    perUser.set(userId, cur);
  });

  const entries = Array.from(perUser.entries());
  let batch = db.batch();
  let ops = 0;

  for (const [userId, agg] of entries) {
    const ref = db.collection("users").doc(userId);
    batch.set(
      ref,
      {
        totalRecycled: agg.grams,
        depositCount: agg.count,
        points: agg.points,
        aggregatesRebuiltAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    ops++;
    if (ops >= 450) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  if (ops > 0) await batch.commit();

  return {
    success: true,
    usersUpdated: entries.length,
    depositsScanned: snap.size,
  };
});

// ===============================================================
//  FUNCTION 9: Create time-limited QR session (user)
//  App calls this to display QR token (NOT uid)
// ===============================================================
exports.createQrSession = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required.");
  }

  const uid = request.auth.uid;

  // 32-char random token
  const token = crypto.randomBytes(16).toString("hex");

  const expiresInSeconds = 60;
  const nowMs = Date.now();
  const expiresAt = Timestamp.fromMillis(nowMs + expiresInSeconds * 1000);

  // ✅ NEW: expire any previous active sessions for this uid
  const activeSnap = await db
    .collection("qrSessions")
    .where("uid", "==", uid)
    .where("status", "==", "active")
    .get();

  const batch = db.batch();

  activeSnap.forEach((doc) => {
    batch.set(
      doc.ref,
      {
        status: "expired",
        expiredAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  // create new active token
  const newRef = db.collection("qrSessions").doc(token);
  batch.set(newRef, {
    uid,
    status: "active", // active | used | expired
    createdAt: FieldValue.serverTimestamp(),
    expiresAt,
    usedAt: null,
    usedByKioskId: null,
  });

  await batch.commit();

  // ✅ return expiresAtMs so app can do accurate countdown
  return {
    success: true,
    token,
    expiresInSeconds,
    expiresAtMs: expiresAt.toMillis(),
  };
});

// ===============================================================
//  FUNCTION 10: Consume QR session (kiosk calls this)
//  Kiosk scans token -> server validates -> returns uid
// ===============================================================
exports.consumeQrSession = onCall({ region: REGION }, async (request) => {
  await assertKiosk(request);

  const { token, kioskId } = request.data || {};
  if (!token || !kioskId) {
    throw new HttpsError("invalid-argument", "Missing token/kioskId.");
  }

  const ref = db.collection("qrSessions").doc(token);

  return await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Invalid QR.");
    }

    const data = snap.data();

    if (data.status !== "active") {
      throw new HttpsError("failed-precondition", "QR already used/expired.");
    }

    const expiresAt = data.expiresAt?.toDate?.();
    if (!expiresAt || expiresAt.getTime() < Date.now()) {
      tx.update(ref, { status: "expired" });
      throw new HttpsError("deadline-exceeded", "QR expired.");
    }

    // ✅ mark as used (single-use)
    tx.update(ref, {
      status: "used",
      usedAt: FieldValue.serverTimestamp(),
      usedByKioskId: kioskId,
    });

    return { success: true, uid: data.uid };
  });
});

exports.cleanupQrSessions = onSchedule(
  {
    region: REGION,
    schedule: "every day 03:00",
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const now = Timestamp.now();

    const cutoffUsedMs = Date.now() - 24 * 60 * 60 * 1000; // 24h ago
    const cutoffUsedAt = Timestamp.fromMillis(cutoffUsedMs);

    let totalExpired = 0;
    let totalUsedOld = 0;

    // helper: delete in batches
    async function deleteByQuery(q, label) {
      while (true) {
        const snap = await q.limit(500).get();
        if (snap.empty) break;

        let batch = db.batch();
        let ops = 0;

        for (const d of snap.docs) {
          batch.delete(d.ref);
          ops++;

          if (ops >= 450) {
            await batch.commit();
            batch = db.batch();
            ops = 0;
          }
        }

        if (ops > 0) await batch.commit();

        if (label === "expired") totalExpired += snap.size;
        if (label === "usedOld") totalUsedOld += snap.size;
      }
    }

    // delete expired (any status) where expiresAt <= now
    await deleteByQuery(
      db.collection("qrSessions").where("expiresAt", "<=", now),
      "expired"
    );

    // delete used sessions where usedAt <= cutoff
    await deleteByQuery(
      db
        .collection("qrSessions")
        .where("status", "==", "used")
        .where("usedAt", "<=", cutoffUsedAt),
      "usedOld"
    );

    console.log(`cleanupQrSessions: expired=${totalExpired}, usedOld=${totalUsedOld}`);
  }
);

exports.sendMonthlyImpactEmails = onSchedule(
  {
    region: REGION,
    schedule: "0 9 1 * *", // 09:00 on day 1 every month
    timeZone: "Asia/Kuala_Lumpur",
    secrets: [SENDGRID_API_KEY],
  },
  async () => {
    sgMail.setApiKey(SENDGRID_API_KEY.value());

    // Query users who enabled email updates
    const snap = await db
      .collection("users")
      .where("emailUpdates", "==", true)
      .get();

    if (snap.empty) {
      console.log("sendMonthlyImpactEmails: no users opted-in.");
      return;
    }

    let sent = 0;
    let skipped = 0;
    let failed = 0;

    // Send one-by-one (safe/simple). You can optimize later.
    for (const doc of snap.docs) {
      const u = doc.data() || {};
      const email = u.email;
      if (!email) {
        skipped++;
        continue;
      }

      const name = u.name || email.split("@")[0] || "there";

      // Use your existing aggregate fields
      const points = u.points ?? 0;
      const totalRecycled = u.totalRecycled ?? 0; // grams
      const depositCount = u.depositCount ?? 0;

      const totalKg = (Number(totalRecycled) / 1000).toFixed(2);

      const subject = "Your Monthly UCO Impact Report 🌱";

      const text = `
Hi ${name},

Here is your monthly impact summary:

• Total deposits: ${depositCount}
• Total recycled: ${totalKg} kg
• Current points: ${points}

Thank you for helping keep used cooking oil out of drains and the environment!

— UCO Kiosk App
      `.trim();

      const html = `
        <div style="font-family:Arial,sans-serif;line-height:1.5">
          <h2>Your Monthly UCO Impact Report 🌱</h2>
          <p>Hi <b>${name}</b>,</p>
          <p>Here is your monthly impact summary:</p>
          <ul>
            <li><b>Total deposits:</b> ${depositCount}</li>
            <li><b>Total recycled:</b> ${totalKg} kg</li>
            <li><b>Current points:</b> ${points}</li>
          </ul>
          <p>Thank you for helping keep used cooking oil out of drains and the environment!</p>
          <p style="color:#6B7280">— UCO Kiosk App</p>
        </div>
      `;

      try {
        await sgMail.send({
          to: email,
          from: EMAIL_FROM,
          subject,
          text,
          html,
        });

        sent++;
      } catch (err) {
        failed++;
        console.error(`Email failed for uid=${doc.id} email=${email}`, err);
      }
    }

    console.log(
      `sendMonthlyImpactEmails done. sent=${sent}, skipped=${skipped}, failed=${failed}`
    );
  }
);

exports.sendTestEmail = onCall(
  { region: REGION, secrets: [SENDGRID_API_KEY] },
  async (request) => {
    // Optional: allow admin only (recommended)
    // await assertAdmin(request);

    const { to } = request.data || {};
    if (!to) throw new HttpsError("invalid-argument", "Missing to email.");

    sgMail.setApiKey(SENDGRID_API_KEY.value());

    await sgMail.send({
      to,
      from: EMAIL_FROM,
      subject: "SendGrid test ✅",
      text: "If you received this, SendGrid + Firebase Functions secrets are working.",
      html: "<b>If you received this, SendGrid + Firebase Functions secrets are working.</b>",
    });

    return { success: true };
  }
);

exports.sendMonthlyImpactEmailsManual = onCall(
  {
    region: REGION,
    secrets: [SENDGRID_API_KEY],
  },
  async (request) => {
    // 🔒 Admin protection (reuse your existing helper)
    await assertAdmin(request);

    sgMail.setApiKey(SENDGRID_API_KEY.value());

    const snap = await db
      .collection("users")
      .where("emailUpdates", "==", true)
      .get();

    if (snap.empty) {
      return {
        success: true,
        sent: 0,
        skipped: 0,
        failed: 0,
        message: "No users opted in",
      };
    }

    let sent = 0;
    let skipped = 0;
    let failed = 0;

    for (const doc of snap.docs) {
      const u = doc.data() || {};
      const email = u.email;

      if (!email) {
        skipped++;
        continue;
      }

      const name = u.name || email.split("@")[0] || "there";
      const points = u.points ?? 0;
      const totalRecycled = u.totalRecycled ?? 0;
      const depositCount = u.depositCount ?? 0;
      const totalKg = (Number(totalRecycled) / 1000).toFixed(2);

      const subject = "Your Monthly UCO Impact Report 🌱";

      const text = `
Hi ${name},

Here is your monthly impact summary:

• Total deposits: ${depositCount}
• Total recycled: ${totalKg} kg
• Current points: ${points}

Thank you for helping keep used cooking oil out of drains and the environment!

— UCO Kiosk App
      `.trim();

      const html = `
        <div style="font-family:Arial,sans-serif;line-height:1.5">
          <h2>Your Monthly UCO Impact Report 🌱</h2>
          <p>Hi <b>${name}</b>,</p>
          <ul>
            <li><b>Total deposits:</b> ${depositCount}</li>
            <li><b>Total recycled:</b> ${totalKg} kg</li>
            <li><b>Current points:</b> ${points}</li>
          </ul>
          <p>Thank you for helping keep used cooking oil out of drains.</p>
          <p style="color:#6B7280">— UCO Kiosk App</p>
        </div>
      `;

      try {
        await sgMail.send({
          to: email,
          from: EMAIL_FROM,
          subject,
          text,
          html,
        });
        sent++;
      } catch (err) {
        failed++;
        console.error(`Manual email failed uid=${doc.id}`, err);
      }
    }

    return {
      success: true,
      sent,
      skipped,
      failed,
    };
  }
);
