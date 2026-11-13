/**
 * Emulator integration tests for Cloud Functions.
 *
 * Run with: npm test
 *
 * Requires the Firebase emulator to be running:
 *   firebase emulators:start --only functions,firestore,auth
 *
 * Or run tests in offline mode using firebase-functions-test with emulator project.
 */

import * as chai from 'chai';
import * as admin from 'firebase-admin';
// eslint-disable-next-line @typescript-eslint/no-require-imports
const functionsTest = require('firebase-functions-test');


const { expect } = chai;

// ─── Emulator setup ──────────────────────────────────────────────────────────
//  Point the Admin SDK to the local emulator suite.
process.env['FIRESTORE_EMULATOR_HOST'] = 'localhost:8080';
process.env['FIREBASE_AUTH_EMULATOR_HOST'] = 'localhost:9099';

const testEnv = functionsTest({
  projectId: 'hisaab-demo',    // must match firebase.json emulators project
});

// Import the wrapped functions AFTER setting up environment vars.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const myFunctions = require('../src/index');

// ─── Helpers ─────────────────────────────────────────────────────────────────
const db = () => admin.firestore();
const auth = () => admin.auth();

const callableContext = (uid: string, role: 'owner' | 'manager') => ({
  auth: { uid, token: { role } },
});

// ─── Tests ────────────────────────────────────────────────────────────────────

describe('createMainBranch', () => {
  const ownerId = 'owner_test_1';

  after(async () => {
    await db().collection('shops').doc(ownerId).delete();
    testEnv.cleanup();
  });

  it('should create a branch and return branchId', async () => {
    const wrapped = testEnv.wrap(myFunctions.createMainBranch);
    const result = await wrapped({ ownerId, name: 'Main Street' }, callableContext(ownerId, 'owner'));

    expect(result).to.have.property('branchId').that.is.a('string');

    const snap = await db()
      .collection('shops')
      .doc(ownerId)
      .collection('branches')
      .doc(result.branchId)
      .get();
    expect(snap.exists).to.be.true;
    expect(snap.data()?.name).to.equal('Main Street');
  });

  it('should throw if ownerId is missing', async () => {
    const wrapped = testEnv.wrap(myFunctions.createMainBranch);
    try {
      await wrapped({ name: 'No Owner' }, callableContext('', 'owner'));
      expect.fail('Should have thrown');
    } catch (err: any) {
      expect(err.code).to.equal('invalid-argument');
    }
  });
});

describe('createSubshop', () => {
  const ownerId = 'owner_test_2';
  let branchId: string;

  before(async () => {
    // Pre-create a branch to attach the subshop to.
    const ref = await db()
      .collection('shops')
      .doc(ownerId)
      .collection('branches')
      .add({ name: 'Test Branch', createdAt: new Date() });
    branchId = ref.id;
  });

  after(async () => {
    // Cleanup: delete shops, counters and any created auth users.
    await db().recursiveDelete(db().collection('shops').doc(ownerId));
    await db().doc('counters/referralId').delete();
    testEnv.cleanup();
  });

  it('should create a subshop with a unique referralId and manager account', async () => {
    const wrapped = testEnv.wrap(myFunctions.createSubshop);
    const result = await wrapped(
      {
        ownerId,
        branchId,
        subshopName: 'Alpha Shop',
        managerUsername: 'mgr_alpha',
        managerPassword: 'Test@1234',
      },
      callableContext(ownerId, 'owner'),
    );

    expect(result).to.have.property('subshopId').that.is.a('string');
    expect(result).to.have.property('referralId').that.is.a('string');

    // Verify Firestore document
    const snap = await db()
      .collection('shops')
      .doc(ownerId)
      .collection('branches')
      .doc(branchId)
      .collection('subshops')
      .doc(result.subshopId)
      .get();
    expect(snap.exists).to.be.true;
    expect(snap.data()?.name).to.equal('Alpha Shop');
    expect(snap.data()?.referralId).to.equal(result.referralId);
    expect(snap.data()?.isActive).to.be.true;

    // Verify Auth user created with synthetic email
    const user = await auth().getUserByEmail('mgr_alpha@manager.hisaab.internal');
    expect(user.displayName).to.equal('mgr_alpha');
  });

  it('referralId should be unique across two subshops', async () => {
    const wrapped = testEnv.wrap(myFunctions.createSubshop);
    const [r1, r2] = await Promise.all([
      wrapped(
        { ownerId, branchId, subshopName: 'Beta', managerUsername: 'mgr_beta', managerPassword: 'Test@5678' },
        callableContext(ownerId, 'owner'),
      ),
      wrapped(
        { ownerId, branchId, subshopName: 'Gamma', managerUsername: 'mgr_gamma', managerPassword: 'Test@9999' },
        callableContext(ownerId, 'owner'),
      ),
    ]);
    expect(r1.referralId).to.not.equal(r2.referralId);
  });

  it('should throw if required fields are missing', async () => {
    const wrapped = testEnv.wrap(myFunctions.createSubshop);
    try {
      await wrapped({ ownerId, branchId }, callableContext(ownerId, 'owner'));
      expect.fail('Should have thrown');
    } catch (err: any) {
      expect(err.code).to.equal('invalid-argument');
    }
  });
});

describe('resetManagerPassword', () => {
  let managerUid: string;

  before(async () => {
    const user = await auth().createUser({
      email: 'reset_test_mgr@example.com',
      password: 'OldPass@123',
      displayName: 'reset_test_mgr',
    });
    managerUid = user.uid;
  });

  after(async () => {
    await auth().deleteUser(managerUid);
    testEnv.cleanup();
  });

  it('should reset the manager password without error', async () => {
    const wrapped = testEnv.wrap(myFunctions.resetManagerPassword);
    const result = await wrapped(
      { managerUid, newPassword: 'NewPass@456' },
      callableContext('some_owner', 'owner'),
    );
    expect(result).to.deep.equal({ success: true });
  });

  it('should throw if managerUid is missing', async () => {
    const wrapped = testEnv.wrap(myFunctions.resetManagerPassword);
    try {
      await wrapped({ newPassword: 'X' }, callableContext('some_owner', 'owner'));
      expect.fail('Should have thrown');
    } catch (err: any) {
      expect(err.code).to.equal('invalid-argument');
    }
  });
});

describe('closeBusinessDay', () => {
  const ownerId = 'owner_close_test';
  const branchId = 'branch_close_1';
  const subshopId = 'subshop_close_1';
  const managerUid = 'mgr_close_uid_1';

  before(async () => {
    const subshopRef = db()
      .collection('shops')
      .doc(ownerId)
      .collection('branches')
      .doc(branchId)
      .collection('subshops')
      .doc(subshopId);

    await subshopRef.set({
      name: 'Close Day Subshop',
      managerUid,
      isActive: true,
      dayStatus: 'open',
    });

    await subshopRef.collection('orders').doc('op_1').set({
      totalPaisa: 1500,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await subshopRef.collection('orders').doc('op_2').set({
      totalPaisa: 2500,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  after(async () => {
    await db().recursiveDelete(db().collection('shops').doc(ownerId));
    testEnv.cleanup();
  });

  it('should close business day, sum sales, store snapshot, update status and record audit log', async () => {
    const wrapped = testEnv.wrap(myFunctions.closeBusinessDay);
    const dayId = '2026-10-15';
    const result = await wrapped(
      {
        dayId,
        date: '2026-10-15T20:00:00Z',
        actualCollectedPaisa: { cash: 3000, card: 1000 },
      },
      callableContext(managerUid, 'manager'),
    );

    expect(result).to.have.property('accepted', true);
    expect(result).to.have.property('duplicate', false);
    expect(result).to.have.property('dayId', dayId);
    expect(result).to.have.property('originalSalesPaisa', 4000);
    expect(result).to.have.property('originalCollectionPaisa', 4000);

    const closedDaySnap = await db()
      .collection('shops')
      .doc(ownerId)
      .collection('branches')
      .doc(branchId)
      .collection('subshops')
      .doc(subshopId)
      .collection('closed_days')
      .doc(dayId)
      .get();

    expect(closedDaySnap.exists).to.be.true;
    expect(closedDaySnap.data()?.originalSalesPaisa).to.equal(4000);
    expect(closedDaySnap.data()?.status).to.equal('closed');

    const subshopSnap = await db()
      .collection('shops')
      .doc(ownerId)
      .collection('branches')
      .doc(branchId)
      .collection('subshops')
      .doc(subshopId)
      .get();

    expect(subshopSnap.data()?.dayStatus).to.equal('closedToday');

    const auditQuery = await db()
      .collection('audit_logs')
      .where('subshopId', '==', subshopId)
      .where('actionType', '==', 'dayClosed')
      .get();

    expect(auditQuery.empty).to.be.false;
  });

  it('should handle idempotent re-calls for the same day', async () => {
    const wrapped = testEnv.wrap(myFunctions.closeBusinessDay);
    const dayId = '2026-10-15';
    const result = await wrapped(
      {
        dayId,
        date: '2026-10-15T20:00:00Z',
        actualCollectedPaisa: { cash: 3000, card: 1000 },
      },
      callableContext(managerUid, 'manager'),
    );

    expect(result).to.have.property('accepted', true);
    expect(result).to.have.property('duplicate', true);
  });

  it('should throw if unauthenticated', async () => {
    const wrapped = testEnv.wrap(myFunctions.closeBusinessDay);
    try {
      await wrapped({ dayId: '2026-10-16', actualCollectedPaisa: 100 }, { auth: undefined });
      expect.fail('Should have thrown');
    } catch (err: any) {
      expect(err.code).to.equal('unauthenticated');
    }
  });
});

describe('checkUnclosedDays', () => {
  const ownerId = 'owner_unclosed_test';
  const branchId = 'branch_unclosed_1';
  const subshopId = 'subshop_unclosed_1';

  before(async () => {
    await db()
      .collection('shops')
      .doc(ownerId)
      .collection('branches')
      .doc(branchId)
      .collection('subshops')
      .doc(subshopId)
      .set({
        name: 'Unclosed Subshop',
        isActive: true,
        dayStatus: 'open',
      });
  });

  after(async () => {
    await db().recursiveDelete(db().collection('shops').doc(ownerId));
    testEnv.cleanup();
  });

  it('should generate an alert for subshops that have not closed their day', async () => {
    const wrapped = testEnv.wrap(myFunctions.checkUnclosedDays);
    await wrapped({});

    const alertsSnap = await db()
      .collection('shops')
      .doc(ownerId)
      .collection('alerts')
      .where('subshopId', '==', subshopId)
      .get();

    expect(alertsSnap.empty).to.be.false;
    const alert = alertsSnap.docs[0].data();
    expect(alert.title).to.equal('Unclosed Business Day');
    expect(alert.isWarning).to.be.true;
  });
});
