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
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
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

// ✅ Shift types
const ALLOWED_SHIFT_TYPES = ["weekday", "weekend"];

// ===========================================
// HELPERS (AUTH)
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

// ✅ kiosk-only callable protection (or allow admin/superadmin for testing)
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

function assertShiftType(shiftType) {
  if (!shiftType || !ALLOWED_SHIFT_TYPES.includes(shiftType)) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid shiftType. Allowed: ${ALLOWED_SHIFT_TYPES.join(", ")}`
    );
  }
}

async function getUserByUid(uid) {
  const snap = await db.collection("users").doc(uid).get();
  return snap.exists ? snap.data() : null;
}

// ===========================================
// HELPERS (TIME / SHIFT)
// Mon–Thu 9–18 = weekday
// Fri–Sun 9–18 = weekend
// If created AFTER 18:00, assign to NEXT day's shift
// ===========================================
const OFFSET_MS = 8 * 60 * 60 * 1000; // Asia/Kuala_Lumpur (no DST)

function weekdayMon1(nowUtcMs) {
  const kl = new Date(nowUtcMs + OFFSET_MS);
  const d = kl.getUTCDay(); // 0=Sun
  return d === 0 ? 7 : d;   // 1=Mon ... 7=Sun
}

function hourKL(nowUtcMs) {
  return new Date(nowUtcMs + OFFSET_MS).getUTCHours(); // KL hour
}

// Returns "weekday" or "weekend" for assignment
function getShiftTypeForAssignment(nowUtcMs) {
  let w = weekdayMon1(nowUtcMs); // 1..7
  const h = hourKL(nowUtcMs);

  // After shift ends (18:00+), push assignment to next day
  if (h >= 18) {
    w = (w === 7) ? 1 : (w + 1);
  }

  // weekday: Mon(1)-Thu(4), weekend: Fri(5)-Sun(7)
  return (w >= 5) ? "weekend" : "weekday";
}

// Pick the single duty agent for (zone + shiftType)
// If multiple exist (shouldn't), we pick lowest agentId/uid for determinism.
async function pickDutyAgentForZone(zone, shiftType) {
  const snap = await db
    .collection("users")
    .where("role", "==", "agent")
    .where("active", "==", true)
    .where("zone", "==", zone)
    .where("shiftType", "==", shiftType)
    .get();

  if (snap.empty) return null;

  const agents = snap.docs.map((d) => ({
    uid: d.id,
    agentId: d.data()?.agentId || "",
  }));

  agents.sort((a, b) => (a.agentId || a.uid).localeCompare(b.agentId || b.uid));
  return agents[0].uid;
}

/**
 * Generate sequential agent code like: AGT-001
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

    // Prevent duplicate active tasks (pending OR in_progress)
    const existing = await db
      .collection("collectionTasks")
      .where("kioskId", "==", kioskId)
      .where("status", "in", ["pending", "in_progress"])
      .get();

    if (!existing.empty) {
      console.log(`Kiosk ${kioskId} already has an active task.`);
      return null;
    }

    console.log(`Creating NEW collection task for kiosk ${kioskId}.`);

    const zone = after.zone || null;

    // ✅ Assign by Zone + Shift (NO round robin)
    let agentUid = null;
    let agentId = null;

    if (zone) {
      const shiftType = getShiftTypeForAssignment(Date.now());
      agentUid = await pickDutyAgentForZone(zone, shiftType);

      if (agentUid) {
        const agentData = await getUserByUid(agentUid);
        agentId = agentData?.agentId || null;
      } else {
        console.log(`No duty agent found for zone=${zone} shiftType=${shiftType}. Task will be unassigned.`);
      }
    }

    return db.collection("collectionTasks").add({
      kioskId,
      kioskName: after.name || after.location || "Unnamed Kiosk",
      zone,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),

      agentUid: agentUid || null,
      agentId: agentId || null,
      assignedAt: agentUid ? FieldValue.serverTimestamp() : null,

      startedAt: null,
      completedAt: null,

      fillLevelAtCreation: after.fillLevel ?? 0,

      proofPhotoUrl: null,
      proofUploadedAt: null,

      // Optional audit for reassign
      reassignedAt: null,
      reassignedFromUid: null,

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
//  FUNCTION 4: Securely Create Agent (admin-only) + AUTO agentId
//  ✅ NEW: requires shiftType = "weekday" | "weekend"
// ===============================================================
exports.createAgent = onCall({ region: REGION }, async (request) => {
  await assertAdmin(request);

  const { email, password, name, phone, zone, shiftType } = request.data || {};
  if (!email || !password || !name) {
    throw new HttpsError("invalid-argument", "Missing email/password/name.");
  }

  assertZone(zone);
  assertShiftType(shiftType);

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
      agentId,
      phone: phone || "",
      zone,
      shiftType, // ✅ IMPORTANT
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
    throw new HttpsError("internal", "createAgent failed", {
      originalMessage: error?.message || null,
      originalCode: error?.code || null,
      stack: error?.stack || null,
    });
  }
});

// ===============================================================
//  FUNCTION 5: Securely Delete User (admin-only)
// ===============================================================
exports.deleteUser = onCall({ region: REGION }, async (request) => {
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
//  FUNCTION 6:
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
    if (before.status === after.status) return null;
    if (after.status !== "completed") return null;
    if (after.postProcessedAt) {
      console.log(`Task ${taskId} already post-processed. Skipping.`);
      return null;
    }

    const kioskId = after.kioskId;
    const agentUid = after.agentUid;
    const agentId = after.agentId;

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
// ===============================================================
exports.createQrSession = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required.");
  }

  const uid = request.auth.uid;
  const token = crypto.randomBytes(16).toString("hex");
  const expiresInSeconds = 60;
  const nowMs = Date.now();
  const expiresAt = Timestamp.fromMillis(nowMs + expiresInSeconds * 1000);
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

  const newRef = db.collection("qrSessions").doc(token);
  batch.set(newRef, {
    uid,
    status: "active",
    createdAt: FieldValue.serverTimestamp(),
    expiresAt,
    usedAt: null,
    usedByKioskId: null,
  });

  await batch.commit();

  return {
    success: true,
    token,
    expiresInSeconds,
    expiresAtMs: expiresAt.toMillis(),
  };
});

// ===============================================================
//  FUNCTION 10: Consume QR session (kiosk calls this)
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

    await deleteByQuery(
      db.collection("qrSessions").where("expiresAt", "<=", now),
      "expired"
    );

    await deleteByQuery(
      db
        .collection("qrSessions")
        .where("status", "==", "used")
        .where("usedAt", "<=", cutoffUsedAt),
      "usedOld"
    );

    console.log(
      `cleanupQrSessions: expired=${totalExpired}, usedOld=${totalUsedOld}`
    );
  }
);

// ===============================================================
//  EMAILS
// ===============================================================
exports.sendMonthlyImpactEmails = onSchedule(
  {
    region: REGION,
    schedule: "0 9 1 * *",
    timeZone: "Asia/Kuala_Lumpur",
    secrets: [SENDGRID_API_KEY],
  },
  async () => {
    sgMail.setApiKey(SENDGRID_API_KEY.value());

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

    for (const doc of snap.docs) {
      const u = doc.data() || {};
      const email = u.email;
      if (!email) {
        skipped++;
        continue;
      }

      const name = u.name || email.split("@")[0] || "there";

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
  { region: REGION, secrets: [SENDGRID_API_KEY] },
  async (request) => {
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

// ===============================================================
//  SHIFT HANDOVER CORE (shared by schedule + manual)
// ===============================================================
async function reassignPendingTasksCore(targetShiftType) {
  console.log(`reassignPendingTasksCore: targetShiftType=${targetShiftType}`);

  let total = 0;
  const perZone = {};

  for (const zone of ALLOWED_ZONES) {
    const targetUid = await pickDutyAgentForZone(zone, targetShiftType);
    if (!targetUid) {
      console.log(`No duty agent for zone=${zone}, shiftType=${targetShiftType}`);
      perZone[zone] = 0;
      continue;
    }

    const targetData = await getUserByUid(targetUid);
    const targetAgentId = targetData?.agentId || null;
    const targetAgentName = targetData?.name || targetData?.email || "";

    // ✅ pending + not started (your tasks are created with startedAt: null)
    const tasksSnap = await db
      .collection("collectionTasks")
      .where("zone", "==", zone)
      .where("status", "==", "pending")
      .where("startedAt", "==", null)
      .get();

    if (tasksSnap.empty) {
      perZone[zone] = 0;
      continue;
    }

    const tasks = tasksSnap.docs
      .map((d) => ({ ref: d.ref, data: d.data() }))
      .filter((t) => (t.data.agentUid || null) !== targetUid);

    if (tasks.length === 0) {
      perZone[zone] = 0;
      continue;
    }

    // optional: oldest-first
    tasks.sort((a, b) => {
      const as = a.data.createdAt?.seconds || 0;
      const bs = b.data.createdAt?.seconds || 0;
      return as - bs;
    });

    let batch = db.batch();
    let ops = 0;

    for (const t of tasks) {
      batch.set(
        t.ref,
        {
          agentUid: targetUid,
          agentId: targetAgentId,
          agentName: targetAgentName,
          assignedAt: FieldValue.serverTimestamp(),
          reassignedAt: FieldValue.serverTimestamp(),
          reassignedFromUid: t.data.agentUid || null,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      ops++;
      total++;
      if (ops >= 450) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }

    if (ops > 0) await batch.commit();

    perZone[zone] = tasks.length;
    console.log(`reassignPendingTasksCore: zone=${zone} reassigned=${tasks.length}`);
  }

  return { total, perZone };
}

// ===============================================================
//  SCHEDULED: shift change points
// ===============================================================
exports.reassignPendingTasksByShift = onSchedule(
  {
    region: REGION,
    schedule: "1 18 * * 0,4",
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const targetShiftType = getShiftTypeForAssignment(Date.now());
    await reassignPendingTasksCore(targetShiftType);
  }
);

// ===============================================================
//  MANUAL: callable (admin only) + optional shiftType override
// ===============================================================
exports.reassignPendingTasksByShiftManual = onCall(
  { region: REGION },
  async (request) => {
    await assertAdmin(request);

    const { shiftType } = request.data || {};
    if (shiftType) assertShiftType(shiftType);

    const targetShiftType = shiftType || getShiftTypeForAssignment(Date.now());
    const result = await reassignPendingTasksCore(targetShiftType);

    return { success: true, targetShiftType, reassigned: result.total, perZone: result.perZone };
  }
);
