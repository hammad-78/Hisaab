// functions/src/index.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { createHash } from 'crypto';

admin.initializeApp();

// Helper to generate a new referral ID using a counter document
async function allocateReferralId(): Promise<string> {
  const counterRef = admin.firestore().doc('counters/referralId');
  const result = await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const current = (snap.data()?.value ?? 0) as number;
    const next = current + 1;
    tx.set(counterRef, { value: next });
    return next.toString().padStart(6, '0'); // e.g., 000001
  });
  return result;
}

async function deleteDocumentTree(documentRef: FirebaseFirestore.DocumentReference): Promise<void> {
  const collections = await documentRef.listCollections();
  for (const collection of collections) {
    const documents = await collection.listDocuments();
    for (const document of documents) await deleteDocumentTree(document);
  }
  await documentRef.delete().catch(() => undefined);
}

/**
 * Creates a main branch for an owner.
 * Expected data: { ownerId: string, name: string }
 */
export const createMainBranch = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const { ownerId, name } = data as { ownerId: string; name: string };
  const cleanName = typeof name === 'string' ? name.trim() : '';
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in as the shop owner.');
  }
  if (typeof ownerId !== 'string' || ownerId.trim().length === 0 || cleanName.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'ownerId and name are required');
  }
  if (context.auth.uid !== ownerId) {
    throw new functions.https.HttpsError('permission-denied', 'Only the owner may create a branch.');
  }
  const branchRef = await admin
    .firestore()
    .collection('shops')
    .doc(ownerId)
    .collection('branches')
    .add({ name: cleanName, ownerId, createdAt: admin.firestore.FieldValue.serverTimestamp() });

  return { branchId: branchRef.id };
});

export const deleteSubshop = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const ownerId = String(data?.ownerId ?? '');
  const subshopId = String(data?.subshopId ?? '');
  if (!context.auth || context.auth.uid !== ownerId) {
    throw new functions.https.HttpsError('permission-denied', 'Only the owner may delete a shop.');
  }
  if (!subshopId) throw new functions.https.HttpsError('invalid-argument', 'subshopId is required');
  const matches = await admin.firestore().collectionGroup('subshops').where(admin.firestore.FieldPath.documentId(), '==', subshopId).get();
  const owned = matches.docs.filter((doc) => doc.ref.path.split('/')[1] === ownerId);
  if (owned.length !== 1) throw new functions.https.HttpsError('not-found', 'Shop not found.');
  const managerUid = owned[0].data().managerUid;
  await deleteDocumentTree(owned[0].ref);
  if (typeof managerUid === 'string' && managerUid) {
    await admin.auth().deleteUser(managerUid).catch(() => undefined);
  }
  return { success: true };
});

export const deleteMainBranch = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const ownerId = String(data?.ownerId ?? '');
  const branchId = String(data?.branchId ?? '');
  if (!context.auth || context.auth.uid !== ownerId) {
    throw new functions.https.HttpsError('permission-denied', 'Only the owner may delete a branch.');
  }
  if (!branchId) throw new functions.https.HttpsError('invalid-argument', 'branchId is required');
  const branchRef = admin.firestore().collection('shops').doc(ownerId).collection('branches').doc(branchId);
  const branchSnap = await branchRef.get();
  if (!branchSnap.exists) throw new functions.https.HttpsError('not-found', 'Branch not found.');
  const subshops = await branchRef.collection('subshops').listDocuments();
  for (const subshopRef of subshops) {
    const subshop = await subshopRef.get();
    const managerUid = subshop.data()?.managerUid;
    await deleteDocumentTree(subshopRef);
    if (typeof managerUid === 'string' && managerUid) {
      await admin.auth().deleteUser(managerUid).catch(() => undefined);
    }
  }
  await deleteDocumentTree(branchRef);
  return { success: true };
});

/**
 * Creates a subshop under a main branch, allocates a referralId, and creates a manager auth account.
 * Expected data: {
 *   ownerId: string,
 *   branchId: string,
 *   subshopName: string,
 *   managerUsername: string,
 *   managerPassword: string
 * }
 */
export const createSubshop = functions.https.onCall(async (data, context) => {
  const {
    ownerId,
    branchId,
    subshopName,
    managerUsername,
    managerPassword,
  } = data as {
    ownerId: string;
    branchId: string;
    subshopName: string;
    managerUsername: string;
    managerPassword: string;
  };

  if (!ownerId || !branchId || !subshopName || !managerUsername || !managerPassword) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }
  if (!context.auth || context.auth.uid !== ownerId) {
    throw new functions.https.HttpsError('permission-denied', 'Only the owner may create a subshop.');
  }
  const normalizedUsername = String(managerUsername).trim().toLowerCase()
    .replace(/[_\s]+/g, '.')
    .replace(/[^a-z0-9.-]/g, '')
    .replace(/\.{2,}/g, '.')
    .replace(/^\.+|\.+$/g, '');
  if (normalizedUsername.length < 3 || normalizedUsername.length > 64) {
    throw new functions.https.HttpsError('invalid-argument', 'Use a username with 3–64 letters, numbers, dots, spaces, or underscores.');
  }

  const referralId = await allocateReferralId();
  const managerEmail = `${normalizedUsername}@manager.hisaab.internal`;
  let userRecord;
  try {
    await admin.auth().getUserByEmail(managerEmail);
    throw new functions.https.HttpsError('already-exists', 'This manager username is already in use.');
  } catch (error) {
    if ((error as functions.https.HttpsError).code === 'already-exists') throw error;
    const authError = error as { code?: string };
    if (authError.code !== 'auth/user-not-found') throw error;
  }
  try {
    userRecord = await admin.auth().createUser({
      email: managerEmail,
      password: managerPassword,
      displayName: normalizedUsername,
    });
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'This manager username is already in use.');
    }
    throw error;
  }

  const subshopRef = admin
    .firestore()
    .collection('shops')
    .doc(ownerId)
    .collection('branches')
    .doc(branchId)
    .collection('subshops')
    .doc();

  try {
    await subshopRef.set({
      name: subshopName,
      ownerId,
      branchId,
      referralId,
      managerUsername: normalizedUsername,
      managerUid: userRecord.uid,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      dayStatus: 'notStarted',
    });
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      role: 'manager',
      ownerId,
      branchId,
      subshopId: subshopRef.id,
    });

    const credentialsRef = admin.firestore().collection('managerCredentials').doc(userRecord.uid);
    await credentialsRef.set({ referralId, username: normalizedUsername });

    return { subshopId: subshopRef.id, referralId };
  } catch (error) {
    await admin.auth().deleteUser(userRecord.uid).catch(() => undefined);
    await subshopRef.delete().catch(() => undefined);
    throw error;
  }
});

/**
 * Resets a manager's password.
 * Expected data: { managerUid: string, newPassword: string }
 */
export const resetManagerPassword = functions.https.onCall(async (data, context) => {
  const { managerUid, newPassword } = data as { managerUid: string; newPassword: string };
  if (!managerUid || !newPassword) {
    throw new functions.https.HttpsError('invalid-argument', 'managerUid and newPassword are required');
  }
  if (!context.auth || newPassword.length < 8) {
    throw new functions.https.HttpsError('permission-denied', 'An owner session and a password of at least 8 characters are required.');
  }
  const managerShops = await admin.firestore().collectionGroup('subshops')
    .where('managerUid', '==', managerUid)
    .limit(2)
    .get();
  if (managerShops.size !== 1 || managerShops.docs[0].ref.path.split('/')[1] !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Only the manager’s owner may reset this password.');
  }
  await admin.auth().updateUser(managerUid, { password: newPassword });
  return { success: true };
});

// This authenticated bootstrap call must work before an installation's App
// Check token has been provisioned. It only updates the caller's own session
// and derives claims from server-owned shop assignments; subsequent write
// operations remain App Check enforced.
export const claimDeviceSession = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  const sessionId = data?.sessionId;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in before claiming a device session.');
  }
  if (typeof sessionId !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(sessionId)) {
    throw new functions.https.HttpsError('invalid-argument', 'A valid device session ID is required.');
  }
  const db = admin.firestore();
  const managerMatches = await db.collectionGroup('subshops')
    .where('managerUid', '==', uid)
    .limit(2)
    .get();
  if (managerMatches.size > 1 ||
      (managerMatches.size === 1 && managerMatches.docs[0].data().isActive !== true)) {
    throw new functions.https.HttpsError('permission-denied', 'This account is not assigned to one active shop.');
  }
  const claims = managerMatches.size === 1
    ? {
        role: 'manager',
        ownerId: managerMatches.docs[0].ref.path.split('/')[1],
        branchId: managerMatches.docs[0].ref.path.split('/')[3],
        subshopId: managerMatches.docs[0].id,
      }
    : { role: 'owner' };
  await admin.auth().setCustomUserClaims(uid, claims);
  await db.collection('device_sessions').doc(uid).set({
    uid,
    sessionId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { accepted: true, sessionId };
});

const managerDataCollections: Record<string, string> = {
  waiter: 'waiters',
  menuCategory: 'menu_categories',
  menuItem: 'menu_items',
  shift: 'shifts',
  managerSettings: '',
};

/** Persist one local-first manager catalog mutation idempotently. */
export const syncManagerData = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const managerUid = context.auth?.uid;
  if (!managerUid) throw new functions.https.HttpsError('unauthenticated', 'Sign in as a manager to sync shop data.');
  const operationId = data?.operationId;
  const entityType = data?.entityType;
  const entityId = data?.entityId;
  const entityData = data?.data;
  if (typeof operationId !== 'string' || !/^[0-9a-f-]{36}$/i.test(operationId) ||
      typeof entityType !== 'string' || !(entityType in managerDataCollections) ||
      typeof entityId !== 'string' || entityId.length === 0 || entityId.length > 128 ||
      entityData === null || typeof entityData !== 'object' || Array.isArray(entityData)) {
    throw new functions.https.HttpsError('invalid-argument', 'Manager data operation is invalid.');
  }

  const allowedFields: Record<string, string[]> = {
    waiter: ['name', 'isActive'],
    menuCategory: ['name', 'isActive'],
    menuItem: ['name', 'pricePaisa', 'categoryId', 'isActive'],
    shift: ['name', 'startTime', 'endTime', 'isActive'],
    managerSettings: ['activeShiftId'],
  };
  const patch: Record<string, string | number | boolean> = {};
  for (const [key, value] of Object.entries(entityData as Record<string, unknown>)) {
    if (!allowedFields[entityType].includes(key)) {
      throw new functions.https.HttpsError('invalid-argument', 'Manager data contains an unsupported field.');
    }
    if (key === 'pricePaisa') {
      if (typeof value !== 'number' || !Number.isSafeInteger(value) || value <= 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Menu prices must be positive integer paisa.');
      }
    } else if (key === 'isActive') {
      if (typeof value !== 'boolean') throw new functions.https.HttpsError('invalid-argument', 'isActive must be boolean.');
    } else if (typeof value !== 'string' || value.trim().length === 0 || value.length > 200) {
      throw new functions.https.HttpsError('invalid-argument', `${key} must be a non-empty string.`);
    }
    patch[key] = value as string | number | boolean;
  }
  if (Object.keys(patch).length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Manager data operation has no changes.');
  }

  const db = admin.firestore();
  const matches = await db.collectionGroup('subshops').where('managerUid', '==', managerUid).limit(2).get();
  if (matches.size !== 1 || matches.docs[0].data().isActive !== true) {
    throw new functions.https.HttpsError('permission-denied', 'This manager is not assigned to an active subshop.');
  }
  const subshopRef = matches.docs[0].ref;
  const targetRef = entityType === 'managerSettings'
    ? subshopRef
    : subshopRef.collection(managerDataCollections[entityType]).doc(entityId);
  const receiptRef = subshopRef.collection('operation_receipts').doc(operationId);
  const canonicalPayload = JSON.stringify({ entityType, entityId, data: patch });
  const payloadHash = createHash('sha256').update(canonicalPayload).digest('hex');

  return db.runTransaction(async (transaction) => {
    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data()?.payloadHash !== payloadHash) {
        throw new functions.https.HttpsError('already-exists', 'Operation ID was reused for different data.');
      }
      return { accepted: true, duplicate: true, operationId };
    }
    const [subshop, existing] = await Promise.all([
      transaction.get(subshopRef),
      transaction.get(targetRef),
    ]);
    if (!subshop.exists || subshop.data()?.isActive !== true) {
      throw new functions.https.HttpsError('permission-denied', 'This subshop is no longer active.');
    }
    transaction.set(targetRef, {
      ...(existing.data() ?? {}),
      ...patch,
      id: entityId,
      version: (existing.data()?.version ?? 0) + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: managerUid,
    });
    transaction.create(receiptRef, {
      operationId,
      payloadHash,
      entityType,
      entityId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { accepted: true, duplicate: false, operationId };
  });
});

type SubmittedOrderLine = {
  menuItemId: string;
  pricePaisa: number;
  quantity: number;
};

function isPositiveSafeInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value > 0;
}

function invalidOrder(message: string): never {
  throw new functions.https.HttpsError('invalid-argument', message);
}

/**
 * Accepts one manager order. The server derives the manager's subshop from
 * their authenticated UID and uses operationId as the Firestore document ID.
 */
export const submitOrder = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const managerUid = context.auth?.uid;
  if (!managerUid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in as a manager to submit orders.');
  }

  const operationId = data?.operationId;
  const orderId = data?.orderId;
  const waiterId = data?.waiterId;
  const shiftId = data?.shiftId;
  const totalPaisa = data?.totalPaisa;
  const createdAtLocal = data?.createdAtLocal;
  const lines = data?.lines;

  if (typeof operationId !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(operationId) ||
      typeof orderId !== 'string' || orderId.length === 0 || orderId.length > 128 ||
      typeof waiterId !== 'string' || waiterId.length === 0 || waiterId.length > 128 ||
      typeof shiftId !== 'string' || shiftId.length > 128 ||
      !isPositiveSafeInteger(totalPaisa) ||
      typeof createdAtLocal !== 'string' || Number.isNaN(Date.parse(createdAtLocal)) ||
      !Array.isArray(lines) || lines.length === 0 || lines.length > 100) {
    invalidOrder('Order fields are missing or invalid.');
  }

  const normalizedLines: SubmittedOrderLine[] = [];
  const seenMenuItems = new Set<string>();
  let calculatedTotal = 0;
  for (const candidate of lines as unknown[]) {
    if (candidate === null || typeof candidate !== 'object') {
      invalidOrder('An order line is invalid.');
    }
    const line = candidate as Partial<SubmittedOrderLine>;
    if (typeof line.menuItemId !== 'string' || line.menuItemId.length === 0 ||
        line.menuItemId.length > 128 || seenMenuItems.has(line.menuItemId) ||
        !isPositiveSafeInteger(line.pricePaisa) || !isPositiveSafeInteger(line.quantity)) {
      invalidOrder('An order line is invalid.');
    }
    seenMenuItems.add(line.menuItemId);
    const lineTotal = line.pricePaisa * line.quantity;
    if (!Number.isSafeInteger(lineTotal) || !Number.isSafeInteger(calculatedTotal + lineTotal)) {
      invalidOrder('Order total is outside the supported range.');
    }
    calculatedTotal += lineTotal;
    normalizedLines.push({
      menuItemId: line.menuItemId,
      pricePaisa: line.pricePaisa,
      quantity: line.quantity,
    });
  }
  if (calculatedTotal !== totalPaisa) {
    invalidOrder('Order total does not match its line items.');
  }

  const db = admin.firestore();
  const matches = await db.collectionGroup('subshops')
    .where('managerUid', '==', managerUid)
    .limit(2)
    .get();
  if (matches.size !== 1 || matches.docs[0].data().isActive !== true) {
    throw new functions.https.HttpsError('permission-denied', 'This manager is not assigned to an active subshop.');
  }
  const subshopRef = matches.docs[0].ref;
  const orderRef = subshopRef.collection('orders').doc(operationId);
  const canonicalPayload = JSON.stringify({
    orderId,
    waiterId,
    shiftId,
    totalPaisa,
    createdAtLocal,
    lines: [...normalizedLines].sort((a, b) => a.menuItemId.localeCompare(b.menuItemId)),
  });
  const payloadHash = createHash('sha256').update(canonicalPayload).digest('hex');
  const dateParts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Karachi',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const datePart = (type: string) => dateParts.find((part) => part.type === type)?.value ?? '';
  const businessDate = `${datePart('year')}-${datePart('month')}-${datePart('day')}`;

  return db.runTransaction(async (transaction) => {
    const existing = await transaction.get(orderRef);
    if (existing.exists) {
      if (existing.data()?.payloadHash !== payloadHash) {
        throw new functions.https.HttpsError('already-exists', 'Operation ID was already used for a different order.');
      }
      return { accepted: true, duplicate: true, operationId };
    }

    const subshop = await transaction.get(subshopRef);
    if (!subshop.exists || subshop.data()?.isActive !== true) {
      throw new functions.https.HttpsError('permission-denied', 'This subshop is no longer active.');
    }
    const subshopData = subshop.data() ?? {};
    const priorSales = subshopData.dashboardDate === businessDate &&
        typeof subshopData.todaySalesPaisa === 'number' && Number.isSafeInteger(subshopData.todaySalesPaisa)
      ? subshopData.todaySalesPaisa
      : 0;
    const priorOrderCount = subshopData.dashboardDate === businessDate &&
        typeof subshopData.todayOrderCount === 'number' && Number.isSafeInteger(subshopData.todayOrderCount)
      ? subshopData.todayOrderCount
      : 0;

    transaction.create(orderRef, {
      operationId,
      localOrderId: orderId,
      waiterId,
      shiftId,
      totalPaisa,
      lines: normalizedLines,
      createdAtLocal,
      businessDate,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      submittedBy: managerUid,
      payloadHash,
    });
    transaction.update(subshopRef, {
      dashboardDate: businessDate,
      todaySalesPaisa: priorSales + totalPaisa,
      todayOrderCount: priorOrderCount + 1,
      lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
      dayStatus: 'open',
    });
    return { accepted: true, duplicate: false, operationId };
  });
});

/**
 * Closes a business day for a manager's subshop.
 * Calculates total sales from subshop orders, creates an immutable closed_day record snapshot,
 * updates the subshop status to 'closedToday', records an audit log entry,
 * and sends an FCM push notification to the owner.
 */
export const closeBusinessDay = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const managerUid = context.auth?.uid;
  if (!managerUid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in as a manager to close business day.');
  }

  const rawDayId = data?.dayId;
  const rawDate = data?.date;
  const rawActualCollectedPaisa = data?.actualCollectedPaisa;

  const dayId = typeof rawDayId === 'string' && rawDayId.trim().length > 0
    ? rawDayId.trim()
    : new Date().toISOString().split('T')[0];
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dayId) || Number.isNaN(Date.parse(`${dayId}T00:00:00Z`))) {
    throw new functions.https.HttpsError('invalid-argument', 'dayId must be a valid YYYY-MM-DD business date.');
  }

  const dateStr = typeof rawDate === 'string' && !Number.isNaN(Date.parse(rawDate))
    ? rawDate
    : new Date().toISOString();

  let originalCollectionPaisa = 0;
  const normalizedActualMap: Record<string, number> = {};

  if (typeof rawActualCollectedPaisa === 'number' && Number.isSafeInteger(rawActualCollectedPaisa) && rawActualCollectedPaisa >= 0) {
    originalCollectionPaisa = rawActualCollectedPaisa;
    normalizedActualMap['total'] = rawActualCollectedPaisa;
  } else if (rawActualCollectedPaisa !== null && typeof rawActualCollectedPaisa === 'object') {
    for (const [key, value] of Object.entries(rawActualCollectedPaisa as Record<string, unknown>)) {
      if (typeof value === 'number' && Number.isSafeInteger(value) && value >= 0) {
        normalizedActualMap[key] = value;
        originalCollectionPaisa += value;
      }
    }
  } else {
    throw new functions.https.HttpsError('invalid-argument', 'actualCollectedPaisa must be a non-negative integer or object map.');
  }

  const db = admin.firestore();
  const matches = await db.collectionGroup('subshops')
    .where('managerUid', '==', managerUid)
    .limit(2)
    .get();

  if (matches.size !== 1 || matches.docs[0].data().isActive !== true) {
    throw new functions.https.HttpsError('permission-denied', 'This manager is not assigned to an active subshop.');
  }

  const subshopDoc = matches.docs[0];
  const subshopRef = subshopDoc.ref;
  const subshopData = subshopDoc.data();
  const subshopId = subshopRef.id;
  const pathSegments = subshopRef.path.split('/');
  const ownerId = pathSegments[1];

  const closedDayRef = subshopRef.collection('closed_days').doc(dayId);
  const canonicalPayload = JSON.stringify({
    dayId,
    originalCollectionPaisa,
    actualCollectedPaisa: normalizedActualMap,
  });
  const payloadHash = createHash('sha256').update(canonicalPayload).digest('hex');

  const result = await db.runTransaction(async (transaction) => {
    const existingSnap = await transaction.get(closedDayRef);
    if (existingSnap.exists) {
      const existingData = existingSnap.data();
      if (existingData?.payloadHash === payloadHash || existingData?.status === 'closed') {
        return {
          accepted: true,
          duplicate: true,
          dayId,
          originalSalesPaisa: existingData?.originalSalesPaisa ?? 0,
          originalCollectionPaisa: existingData?.originalCollectionPaisa ?? 0,
        };
      }
      throw new functions.https.HttpsError('already-exists', 'Business day was already closed with different data.');
    }

    const ordersQuery = subshopRef.collection('orders').where('businessDate', '==', dayId);
    const ordersSnap = await transaction.get(ordersQuery);
    let originalSalesPaisa = 0;
    let orderCount = 0;

    ordersSnap.forEach((doc) => {
      const orderData = doc.data();
      if (typeof orderData.totalPaisa === 'number' && Number.isSafeInteger(orderData.totalPaisa)) {
        originalSalesPaisa += orderData.totalPaisa;
      }
      orderCount++;
    });

    // Create immutable snapshot of closed day record
    transaction.set(closedDayRef, {
      dayId,
      ownerId,
      subshopId,
      subshopName: subshopData.name,
      date: dateStr,
      originalSalesPaisa,
      originalCollectionPaisa,
      actualCollectedPaisa: normalizedActualMap,
      orderCount,
      closedBy: managerUid,
      closedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      adjustments: [],
      status: 'closed',
      payloadHash,
    });

    // Update subshop dayStatus
    transaction.update(subshopRef, {
      dayStatus: 'closedToday',
      lastClosedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastClosedDayId: dayId,
    });

    // Record audit log entry
    const auditRef = db.collection('audit_logs').doc();
    transaction.set(auditRef, {
      action: 'Day Closed',
      actionType: 'dayClosed',
      subshopId,
      subshopName: subshopData.name,
      ownerId,
      performedBy: managerUid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: {
        dayId,
        originalSalesPaisa,
        originalCollectionPaisa,
      },
    });

    return {
      accepted: true,
      duplicate: false,
      dayId,
      originalSalesPaisa,
      originalCollectionPaisa,
    };
  });

  // Send FCM notification to owner
  try {
    const formattedSales = (result.originalSalesPaisa / 100).toFixed(2);
    const formattedCollection = (result.originalCollectionPaisa / 100).toFixed(2);

    await admin.messaging().send({
      notification: {
        title: `Day Closed: ${subshopData.name}`,
        body: `Business day ${dayId} closed. Total Sales: Rs. ${formattedSales}, Collected: Rs. ${formattedCollection}.`,
      },
      data: {
        type: 'day_closed',
        subshopId,
        dayId,
        ownerId,
      },
      topic: `owner_${ownerId}`,
    });
  } catch (fcmError) {
    functions.logger.warn(`Failed to send FCM notification for closeBusinessDay to owner ${ownerId}:`, fcmError);
  }

  return result;
});

/** Append or reverse an owner adjustment on an immutable closed-day snapshot. */
export const adjustClosedDay = functions.https.onCall(async (data, context) => {
  const ownerId = context.auth?.uid;
  const subshopId = data?.subshopId;
  const dayId = data?.dayId;
  const reason = typeof data?.reason === 'string' ? data.reason.trim() : '';
  if (!ownerId) throw new functions.https.HttpsError('unauthenticated', 'Sign in as an owner.');
  const actorName = context.auth?.token.name ?? ownerId;
  if (data?.ownerId !== ownerId || typeof subshopId !== 'string' || typeof dayId !== 'string' || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'Adjustment details are incomplete.');
  }

  const db = admin.firestore();
  const subshops = await db.collectionGroup('subshops').where('ownerId', '==', ownerId).get();
  const subshop = subshops.docs.find((doc) => doc.id === subshopId);
  if (!subshop) throw new functions.https.HttpsError('not-found', 'Shop not found.');

  const closedDayRef = subshop.ref.collection('closed_days').doc(dayId);
  const closedDaySnapshot = await closedDayRef.get();
  if (!closedDaySnapshot.exists || closedDaySnapshot.data()?.ownerId !== ownerId) {
    throw new functions.https.HttpsError('not-found', 'Closed business day not found.');
  }

  const adjustmentId = db.collection('_ids').doc().id;
  const reversedAdjustmentId = data?.reversedAdjustmentId;
  let adjustment: Record<string, unknown>;
  let actionType: string;
  let description: string;
  const priorAdjustments = (closedDaySnapshot.data()?.adjustments ?? []) as Array<Record<string, unknown>>;

  if (typeof reversedAdjustmentId === 'string') {
    const target = priorAdjustments.find((entry) => entry.id === reversedAdjustmentId);
    if (!target || target.isReversal === true || priorAdjustments.some((entry) => entry.reversedAdjustmentId === reversedAdjustmentId)) {
      throw new functions.https.HttpsError('failed-precondition', 'This adjustment cannot be reversed.');
    }
    const type = target.type === 'addition' ? 'deduction' : 'addition';
    adjustment = {
      id: adjustmentId,
      type,
      amountPaisa: target.amountPaisa,
      reason,
      createdAt: admin.firestore.Timestamp.now(),
      createdBy: actorName,
      isReversal: true,
      reversedAdjustmentId,
    };
    actionType = 'adjustmentReversed';
    description = `Reversed adjustment ${reversedAdjustmentId}: ${reason}`;
  } else {
    const type = data?.type;
    const amountPaisa = data?.amountPaisa;
    if ((type !== 'addition' && type !== 'deduction') ||
        typeof amountPaisa !== 'number' || !Number.isSafeInteger(amountPaisa) || amountPaisa <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Enter a valid adjustment type and amount.');
    }
    adjustment = {
      id: adjustmentId,
      type,
      amountPaisa,
      reason,
      createdAt: admin.firestore.Timestamp.now(),
      createdBy: actorName,
      isReversal: false,
    };
    actionType = 'adjustmentCreated';
    description = `${type} adjustment of ${amountPaisa} paisa: ${reason}`;
  }

  const auditRef = db.collection('audit_logs').doc();
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(closedDayRef);
    if (!current.exists || current.data()?.ownerId !== ownerId) {
      throw new functions.https.HttpsError('not-found', 'Closed business day not found.');
    }
    const entries = (current.data()?.adjustments ?? []) as Array<Record<string, unknown>>;
    if (typeof reversedAdjustmentId === 'string') {
      const targetExists = entries.some((entry) => entry.id === reversedAdjustmentId && entry.isReversal !== true);
      const alreadyReversed = entries.some((entry) => entry.reversedAdjustmentId === reversedAdjustmentId);
      if (!targetExists || alreadyReversed) {
        throw new functions.https.HttpsError('failed-precondition', 'This adjustment can no longer be reversed.');
      }
    }
    transaction.update(closedDayRef, { adjustments: [...entries, adjustment] });
    transaction.set(auditRef, {
      ownerId,
      action: actionType,
      actionType,
      performedBy: actorName,
      targetName: closedDaySnapshot.data()?.subshopName ?? 'Shop',
      subshopId,
      subshopName: closedDaySnapshot.data()?.subshopName ?? 'Shop',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: { dayId, description },
    });
  });

  return { success: true, adjustmentId };
});

/**
 * Scheduled function that checks for any active subshops that have not closed their business day.
 * Generates an owner alert and sends an FCM push notification.
 * Scheduled to run daily at 23:00 UTC (11:00 PM).
 */
export const checkUnclosedDays = functions.pubsub.schedule('0 23 * * *').onRun(async () => {
  const db = admin.firestore();
  const snapshot = await db.collectionGroup('subshops')
    .where('isActive', '==', true)
    .get();

  const unclosedList: Array<{ subshopId: string; subshopName: string; ownerId: string }> = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (data.dayStatus !== 'closedToday') {
      const pathSegments = doc.ref.path.split('/');
      const ownerId = pathSegments[1];
      unclosedList.push({
        subshopId: doc.id,
        subshopName: data.name || 'Subshop',
        ownerId,
      });
    }
  }

  for (const item of unclosedList) {
    try {
      // 1. Create owner alert in Firestore
      await db.collection('shops').doc(item.ownerId).collection('alerts').add({
        title: 'Unclosed Business Day',
        message: `${item.subshopName} has not closed its business day yet.`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isWarning: true,
        subshopId: item.subshopId,
        subshopName: item.subshopName,
        isRead: false,
      });

      // 2. Send FCM notification to owner topic
      await admin.messaging().send({
        notification: {
          title: `Unclosed Day Warning: ${item.subshopName}`,
          body: `${item.subshopName} has not closed its business day today. Please review with manager.`,
        },
        data: {
          type: 'unclosed_day_warning',
          subshopId: item.subshopId,
          ownerId: item.ownerId,
        },
        topic: `owner_${item.ownerId}`,
      });
    } catch (err) {
      functions.logger.error(`Error processing unclosed day warning for subshop ${item.subshopId}:`, err);
    }
  }

  functions.logger.info(`checkUnclosedDays evaluated ${snapshot.size} active subshops, processed ${unclosedList.length} unclosed.`);
  return null;
});
