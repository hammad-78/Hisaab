import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc } from 'firebase/firestore';

const projectId = 'demo-hisaab-security-rules';
let testEnv: RulesTestEnvironment;

before(async () => {
  const rules = fs.readFileSync(path.resolve(__dirname, '../../../firestore.rules'), 'utf8');
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'shops/owner-a'), { name: 'Owner A' });
    await setDoc(doc(db, 'shops/owner-a/branches/branch-a'), { name: 'Branch A' });
    await setDoc(doc(db, 'shops/owner-a/branches/branch-a/subshops/shop-a'), {
      name: 'Shop A',
      managerUid: 'manager-a',
    });
    await setDoc(doc(db, 'shops/owner-a/branches/branch-a/subshops/shop-a/orders/order-a'), {
      totalPaisa: 5000,
    });
    await setDoc(doc(db, 'shops/owner-a/branches/branch-a/subshops/shop-a/waiters/waiter-a'), {
      name: 'Ayesha',
      isActive: true,
    });
    await setDoc(doc(db, 'shops/owner-a/branches/branch-a/subshops/shop-a/menu_items/item-a'), {
      name: 'Tea',
      pricePaisa: 8000,
      isActive: true,
    });
    await setDoc(doc(db, 'shops/owner-b'), { name: 'Owner B' });
    await setDoc(doc(db, 'shops/owner-b/branches/branch-b'), { name: 'Branch B' });
    await setDoc(doc(db, 'shops/owner-b/branches/branch-b/subshops/shop-b'), {
      name: 'Shop B',
      managerUid: 'manager-b',
    });
    await setDoc(doc(db, 'device_sessions/owner-a'), { sessionId: 'session-a' });
    await setDoc(doc(db, 'device_sessions/manager-a'), { sessionId: 'session-manager-a' });
    await setDoc(doc(db, 'audit_logs/audit-a'), { ownerId: 'owner-a' });
  });
});

after(async () => {
  await testEnv?.cleanup();
});

describe('Firestore security rules', () => {
  it('allows an owner to read only their own shop tree', async () => {
    const db = testEnv.authenticatedContext('owner-a').firestore();
    await assertSucceeds(getDoc(doc(db, 'shops/owner-a')));
    await assertSucceeds(getDoc(doc(db, 'shops/owner-a/branches/branch-a')));
    await assertSucceeds(getDoc(doc(db, 'shops/owner-a/branches/branch-a/subshops/shop-a')));
    await assertSucceeds(getDoc(doc(db, 'shops/owner-a/branches/branch-a/subshops/shop-a/orders/order-a')));
    await assertFails(getDoc(doc(db, 'shops/owner-b')));
    await assertFails(getDoc(doc(db, 'shops/owner-b/branches/branch-b/subshops/shop-b')));
  });

  it('allows a manager to read only the subshop named in custom claims', async () => {
    const db = testEnv.authenticatedContext('manager-a', {
      role: 'manager',
      ownerId: 'owner-a',
      branchId: 'branch-a',
      subshopId: 'shop-a',
    }).firestore();
    await assertSucceeds(getDoc(doc(db, 'shops/owner-a/branches/branch-a/subshops/shop-a')));
    await assertSucceeds(getDoc(doc(db, 'shops/owner-a/branches/branch-a/subshops/shop-a/orders/order-a')));
    await assertSucceeds(getDoc(doc(db, 'shops/owner-a/branches/branch-a/subshops/shop-a/waiters/waiter-a')));
    await assertSucceeds(getDoc(doc(db, 'shops/owner-a/branches/branch-a/subshops/shop-a/menu_items/item-a')));
    await assertFails(getDoc(doc(db, 'shops/owner-b/branches/branch-b/subshops/shop-b')));
  });

  it('denies all client writes to protected business data and server-owned collections', async () => {
    const ownerDb = testEnv.authenticatedContext('owner-a').firestore();
    const managerDb = testEnv.authenticatedContext('manager-a', {
      role: 'manager',
      ownerId: 'owner-a',
      branchId: 'branch-a',
      subshopId: 'shop-a',
    }).firestore();
    await assertFails(setDoc(doc(ownerDb, 'shops/owner-a'), { name: 'Changed' }));
    await assertFails(setDoc(doc(ownerDb, 'shops/owner-a/branches/new-branch'), { name: 'New' }));
    await assertFails(setDoc(doc(ownerDb, 'shops/owner-a/branches/branch-a/subshops/new-shop'), { name: 'New' }));
    await assertFails(setDoc(doc(managerDb, 'shops/owner-a/branches/branch-a/subshops/shop-a/orders/order-b'), { totalPaisa: 1 }));
    await assertFails(setDoc(doc(managerDb, 'shops/owner-a/branches/branch-a/subshops/shop-a/waiters/waiter-b'), { name: 'Bilal' }));
    await assertFails(deleteDoc(doc(managerDb, 'shops/owner-a/branches/branch-a/subshops/shop-a/orders/order-a')));
    await assertFails(setDoc(doc(ownerDb, 'device_sessions/owner-a'), { sessionId: 'spoofed' }));
    await assertFails(setDoc(doc(ownerDb, 'counters/referralId'), { value: 99 }));
    await assertFails(setDoc(doc(ownerDb, 'managerCredentials/manager-a'), { username: 'manager-a' }));
    await assertFails(setDoc(doc(ownerDb, 'audit_logs/audit-b'), { ownerId: 'owner-a' }));
  });

  it('allows a user to read only their own session and owner audit events', async () => {
    const ownerDb = testEnv.authenticatedContext('owner-a').firestore();
    await assertSucceeds(getDoc(doc(ownerDb, 'device_sessions/owner-a')));
    await assertSucceeds(getDoc(doc(ownerDb, 'audit_logs/audit-a')));
    await assertFails(getDoc(doc(ownerDb, 'device_sessions/manager-a')));
    await assertFails(getDoc(doc(ownerDb, 'audit_logs/audit-missing')));
    const unauthenticatedDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(unauthenticatedDb, 'shops/owner-a')));
  });
});
