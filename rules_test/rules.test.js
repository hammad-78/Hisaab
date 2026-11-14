// Security rules tests for Hisaab. Run from the project root with:
//   firebase emulators:exec --only firestore --project demo-hisaab "npm --prefix rules_test test"
import { readFileSync } from 'node:fs';
import { test, before, after, beforeEach, describe } from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch,
  collection, query, where, getDocs, serverTimestamp,
} from 'firebase/firestore';

let env;

// owner1 owns cafe c1 (shops s1, s2). owner2 owns cafe c2.
// m1 manages c1/s1, m2 manages c1/s2, m3 manages c2/x1.
const managers = {
  m1: { cafeId: 'c1', shopId: 's1' },
  m2: { cafeId: 'c1', shopId: 's2' },
  m3: { cafeId: 'c2', shopId: 'x1' },
};

const sale = (shopId, createdBy, extra = {}) => ({
  orderId: 'o1', shopId, waiterId: 'w1', waiterName: 'Ali',
  itemId: 'i1', itemName: 'Tea', qty: 2, unitPrice: 50, total: 100,
  day: '2026-11-13', createdAt: serverTimestamp(), createdBy, ...extra,
});

const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-hisaab',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, 'users/owner1'), { name: 'O1', email: 'o1@x', role: 'owner', cafeId: 'c1', shopId: null });
    await setDoc(doc(f, 'users/owner2'), { name: 'O2', email: 'o2@x', role: 'owner', cafeId: 'c2', shopId: null });
    for (const [uid, m] of Object.entries(managers)) {
      await setDoc(doc(f, `users/${uid}`), { name: uid, email: `${uid}@x`, role: 'manager', ...m });
    }
    await setDoc(doc(f, 'cafes/c1'), { name: 'UET', ownerId: 'owner1' });
    await setDoc(doc(f, 'cafes/c2'), { name: 'Other', ownerId: 'owner2' });
    await setDoc(doc(f, 'cafes/c1/shops/s1'), { name: 'SSA', managerUid: 'm1' });
    await setDoc(doc(f, 'cafes/c1/shops/s2'), { name: 'B', managerUid: 'm2' });
    // Each shop has its own menu and waiters.
    await setDoc(doc(f, 'cafes/c1/items/i1'), { name: 'Tea', price: 50, shopId: 's1' });
    await setDoc(doc(f, 'cafes/c1/items/i2'), { name: 'Cake', price: 90, shopId: 's2' });
    await setDoc(doc(f, 'cafes/c1/items/legacy'), { name: 'Old', price: 10 }); // pre-change item, no shop
    await setDoc(doc(f, 'cafes/c1/waiters/w1'), { name: 'Ali', shopId: 's1' });
    await setDoc(doc(f, 'cafes/c1/waiters/w2'), { name: 'Bilal', shopId: 's2' });
    await setDoc(doc(f, 'cafes/c1/sales/sale_s1'), sale('s1', 'm1'));
    await setDoc(doc(f, 'cafes/c1/sales/sale_s2'), sale('s2', 'm2'));
    await setDoc(doc(f, 'cafes/c2/sales/sale_x1'), sale('x1', 'm3'));
  });
});

// ---------------------------------------------------------------- signed out
describe('signed out', () => {
  test('cannot read anything', async () => {
    await assertFails(getDoc(doc(db(null), 'users/owner1')));
    await assertFails(getDoc(doc(db(null), 'cafes/c1')));
    await assertFails(getDocs(collection(db(null), 'cafes/c1/sales')));
  });
});

// ---------------------------------------------------------------- registration
describe('owner registration', () => {
  test('new user can create own owner profile (as the app does)', async () => {
    await assertSucceeds(setDoc(doc(db('new'), 'users/new'),
      { name: 'N', email: 'n@x', role: 'owner', cafeId: null, shopId: null }));
  });
  test('cannot self-register as a manager of someone else\'s shop', async () => {
    await assertFails(setDoc(doc(db('new'), 'users/new'),
      { name: 'N', email: 'n@x', role: 'manager', cafeId: 'c1', shopId: 's1' }));
  });
  test('cannot self-register as owner already linked to a cafe', async () => {
    await assertFails(setDoc(doc(db('new'), 'users/new'),
      { name: 'N', email: 'n@x', role: 'owner', cafeId: 'c1', shopId: null }));
  });
  test('cannot create a profile for another uid', async () => {
    await assertFails(setDoc(doc(db('new'), 'users/someoneElse'),
      { name: 'N', email: 'n@x', role: 'owner', cafeId: null, shopId: null }));
  });
});

// ---------------------------------------------------------------- owner
describe('owner', () => {
  test('creates a cafe and links it to their profile', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users/new'),
      { name: 'N', email: 'n@x', role: 'owner', cafeId: null, shopId: null }));
    const f = db('new');
    await assertSucceeds(setDoc(doc(f, 'cafes/c9'), { name: 'Nine', ownerId: 'new', createdAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(f, 'users/new'), { cafeId: 'c9' }));
  });
  test('cannot create a cafe owned by someone else', async () => {
    await assertFails(setDoc(doc(db('owner1'), 'cafes/c9'), { name: 'X', ownerId: 'owner2' }));
  });
  test('cannot link own profile to another owner\'s cafe', async () => {
    await assertFails(updateDoc(doc(db('owner1'), 'users/owner1'), { cafeId: 'c2' }));
  });
  test('cannot change own role', async () => {
    await assertFails(updateDoc(doc(db('owner1'), 'users/owner1'), { role: 'manager' }));
  });
  test('cannot hand the cafe to another account', async () => {
    await assertFails(updateDoc(doc(db('owner1'), 'cafes/c1'), { ownerId: 'owner2' }));
  });
  test('can rename the cafe', async () => {
    await assertSucceeds(updateDoc(doc(db('owner1'), 'cafes/c1'), { name: 'New name' }));
  });

  test('creates a shop + manager profile in one batch (as the app does)', async () => {
    const f = db('owner1');
    const b = writeBatch(f);
    b.set(doc(f, 'cafes/c1/shops/s3'), { name: 'S3', managerUid: 'm9', managerName: 'M9', managerEmail: 'm9@x', createdAt: serverTimestamp() });
    b.set(doc(f, 'users/m9'), { name: 'M9', email: 'm9@x', role: 'manager', cafeId: 'c1', shopId: 's3' });
    await assertSucceeds(b.commit());
  });
  test('cannot create a manager for another owner\'s cafe', async () => {
    await assertFails(setDoc(doc(db('owner1'), 'users/m9'),
      { name: 'M9', email: 'm9@x', role: 'manager', cafeId: 'c2', shopId: 'x1' }));
  });
  test('cannot create a manager for a shop that does not exist', async () => {
    await assertFails(setDoc(doc(db('owner1'), 'users/m9'),
      { name: 'M9', email: 'm9@x', role: 'manager', cafeId: 'c1', shopId: 'nope' }));
  });
  test('cannot move own manager to a shop that does not exist', async () => {
    await assertFails(updateDoc(doc(db('owner1'), 'users/m1'), { shopId: 'nope' }));
  });
  test('cannot create an extra owner profile for another uid', async () => {
    await assertFails(setDoc(doc(db('owner1'), 'users/m9'),
      { name: 'M9', email: 'm9@x', role: 'owner', cafeId: 'c1', shopId: null }));
  });

  test('can move own manager to another of their shops', async () => {
    await assertSucceeds(updateDoc(doc(db('owner1'), 'users/m1'), { shopId: 's2' }));
  });
  test('cannot move own manager into another owner\'s cafe', async () => {
    await assertFails(updateDoc(doc(db('owner1'), 'users/m1'), { cafeId: 'c2', shopId: 'x1' }));
  });
  test('cannot promote own manager to owner', async () => {
    await assertFails(updateDoc(doc(db('owner1'), 'users/m1'), { role: 'owner' }));
  });
  test('can delete own manager profile', async () => {
    await assertSucceeds(deleteDoc(doc(db('owner1'), 'users/m1')));
  });
  test('cannot touch another owner\'s manager', async () => {
    await assertFails(getDoc(doc(db('owner1'), 'users/m3')));
    await assertFails(updateDoc(doc(db('owner1'), 'users/m3'), { name: 'x' }));
    await assertFails(deleteDoc(doc(db('owner1'), 'users/m3')));
  });

  test('reads every shop\'s menu and waiters (as the Shops tab does)', async () => {
    const f = db('owner1');
    await assertSucceeds(getDocs(query(collection(f, 'cafes/c1/items'))));
    await assertSucceeds(getDocs(query(collection(f, 'cafes/c1/waiters'))));
  });
  test('cannot add, edit or delete menu items or waiters (managers do that)', async () => {
    const f = db('owner1');
    await assertFails(setDoc(doc(f, 'cafes/c1/items/i9'), { name: 'X', price: 1, shopId: 's1' }));
    await assertFails(updateDoc(doc(f, 'cafes/c1/items/i1'), { price: 1 }));
    await assertFails(deleteDoc(doc(f, 'cafes/c1/items/i1')));
    await assertFails(setDoc(doc(f, 'cafes/c1/waiters/w9'), { name: 'X', shopId: 's1' }));
    await assertFails(updateDoc(doc(f, 'cafes/c1/waiters/w1'), { name: 'Y' }));
    await assertFails(deleteDoc(doc(f, 'cafes/c1/waiters/w1')));
  });

  test('reads all sales of own cafe by date range (reports query)', async () => {
    const q = query(collection(db('owner1'), 'cafes/c1/sales'),
      where('day', '>=', '2026-11-01'), where('day', '<=', '2026-11-30'));
    await assertSucceeds(getDocs(q));
  });
  test('cannot read or write another owner\'s cafe', async () => {
    const f = db('owner1');
    await assertFails(getDoc(doc(f, 'cafes/c2')));
    await assertFails(getDocs(collection(f, 'cafes/c2/sales')));
    await assertFails(setDoc(doc(f, 'cafes/c2/items/i9'), { name: 'X', price: 1 }));
  });
  test('cannot add sales directly (only managers record sales)', async () => {
    await assertFails(setDoc(doc(db('owner1'), 'cafes/c1/sales/new'), sale('s1', 'owner1')));
  });
  test('can delete a sale in own cafe', async () => {
    await assertSucceeds(deleteDoc(doc(db('owner1'), 'cafes/c1/sales/sale_s2')));
  });
});

// ---------------------------------------------------------------- manager
describe('manager', () => {
  test('reads own profile, cafe and shops', async () => {
    const f = db('m1');
    await assertSucceeds(getDoc(doc(f, 'users/m1')));
    await assertSucceeds(getDoc(doc(f, 'cafes/c1')));
    await assertSucceeds(getDocs(query(collection(f, 'cafes/c1/shops'))));
  });

  test('reads own shop\'s menu and waiters (as the app does)', async () => {
    const f = db('m1');
    await assertSucceeds(getDocs(query(collection(f, 'cafes/c1/items'), where('shopId', '==', 's1'))));
    await assertSucceeds(getDocs(query(collection(f, 'cafes/c1/waiters'), where('shopId', '==', 's1'))));
  });
  test('cannot read another shop\'s menu or waiters', async () => {
    const f = db('m1');
    await assertFails(getDocs(query(collection(f, 'cafes/c1/items'), where('shopId', '==', 's2'))));
    await assertFails(getDocs(collection(f, 'cafes/c1/items')));
    await assertFails(getDoc(doc(f, 'cafes/c1/items/i2')));
    await assertFails(getDoc(doc(f, 'cafes/c1/waiters/w2')));
    await assertFails(getDoc(doc(f, 'cafes/c1/items/legacy')));
  });

  test('manages own shop\'s menu (as the app does)', async () => {
    const f = db('m1');
    await assertSucceeds(setDoc(doc(f, 'cafes/c1/items/n1'),
      { name: 'Samosa', price: 60, shopId: 's1', createdAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(f, 'cafes/c1/items/n1'), { name: 'Samosa (2 pcs)', price: 110 }));
    await assertSucceeds(deleteDoc(doc(f, 'cafes/c1/items/n1')));
  });
  test('manages own shop\'s waiters (as the app does)', async () => {
    const f = db('m1');
    await assertSucceeds(setDoc(doc(f, 'cafes/c1/waiters/n1'),
      { name: 'Usman', shopId: 's1', createdAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(f, 'cafes/c1/waiters/n1'), { name: 'Usman Ali' }));
    await assertSucceeds(deleteDoc(doc(f, 'cafes/c1/waiters/n1')));
  });
  test('cannot touch another shop\'s menu or waiters', async () => {
    const f = db('m1');
    await assertFails(setDoc(doc(f, 'cafes/c1/items/x'), { name: 'X', price: 1, shopId: 's2' }));
    await assertFails(updateDoc(doc(f, 'cafes/c1/items/i2'), { price: 1 }));
    await assertFails(deleteDoc(doc(f, 'cafes/c1/items/i2')));
    await assertFails(setDoc(doc(f, 'cafes/c1/waiters/x'), { name: 'X', shopId: 's2' }));
    await assertFails(deleteDoc(doc(f, 'cafes/c1/waiters/w2')));
    await assertFails(setDoc(doc(f, 'cafes/c2/items/x'), { name: 'X', price: 1, shopId: 'x1' }));
  });
  test('cannot move an item or waiter to another shop', async () => {
    const f = db('m1');
    await assertFails(updateDoc(doc(f, 'cafes/c1/items/i1'), { shopId: 's2' }));
    await assertFails(updateDoc(doc(f, 'cafes/c1/waiters/w1'), { shopId: 's2' }));
  });
  test('rejects bad menu data', async () => {
    const f = db('m1');
    await assertFails(setDoc(doc(f, 'cafes/c1/items/x'), { name: '', price: 10, shopId: 's1' }));
    await assertFails(setDoc(doc(f, 'cafes/c1/items/x'), { name: 'Tea', price: -5, shopId: 's1' }));
    await assertFails(setDoc(doc(f, 'cafes/c1/items/x'), { name: 'Tea', price: '50', shopId: 's1' }));
    await assertFails(setDoc(doc(f, 'cafes/c1/waiters/x'), { name: '', shopId: 's1' }));
  });
  test('cannot read other users\' profiles', async () => {
    await assertFails(getDoc(doc(db('m1'), 'users/m2')));
    await assertFails(getDoc(doc(db('m1'), 'users/owner1')));
  });
  test('cannot change own profile (e.g. switch shop or cafe)', async () => {
    await assertFails(updateDoc(doc(db('m1'), 'users/m1'), { shopId: 's2' }));
    await assertFails(updateDoc(doc(db('m1'), 'users/m1'), { role: 'owner' }));
    await assertFails(updateDoc(doc(db('m1'), 'users/m1'), { cafeId: 'c2' }));
  });
  test('cannot edit shops or the cafe', async () => {
    const f = db('m1');
    await assertFails(setDoc(doc(f, 'cafes/c1/shops/s9'), { name: 'X' }));
    await assertFails(updateDoc(doc(f, 'cafes/c1/shops/s1'), { name: 'X' }));
    await assertFails(updateDoc(doc(f, 'cafes/c1'), { name: 'X' }));
  });
  test('cannot read another cafe', async () => {
    await assertFails(getDoc(doc(db('m1'), 'cafes/c2')));
    await assertFails(getDocs(collection(db('m1'), 'cafes/c2/items')));
  });

  test('places a multi-item order for own shop (as the app does)', async () => {
    const f = db('m1');
    const b = writeBatch(f);
    b.set(doc(f, 'cafes/c1/sales/a'), sale('s1', 'm1', { orderId: 'o9' }));
    b.set(doc(f, 'cafes/c1/sales/b'), sale('s1', 'm1', { orderId: 'o9', itemId: 'i2', qty: 1 }));
    await assertSucceeds(b.commit());
  });
  test('cannot record a sale for another shop', async () => {
    await assertFails(setDoc(doc(db('m1'), 'cafes/c1/sales/x'), sale('s2', 'm1')));
  });
  test('cannot record a sale in another cafe', async () => {
    await assertFails(setDoc(doc(db('m1'), 'cafes/c2/sales/x'), sale('x1', 'm1')));
  });
  test('cannot record a sale as someone else', async () => {
    await assertFails(setDoc(doc(db('m1'), 'cafes/c1/sales/x'), sale('s1', 'm2')));
  });
  test('rejects zero, negative or fractional quantities', async () => {
    const f = db('m1');
    await assertFails(setDoc(doc(f, 'cafes/c1/sales/x'), sale('s1', 'm1', { qty: 0 })));
    await assertFails(setDoc(doc(f, 'cafes/c1/sales/x'), sale('s1', 'm1', { qty: -3 })));
    await assertFails(setDoc(doc(f, 'cafes/c1/sales/x'), sale('s1', 'm1', { qty: 1.5 })));
  });

  test('reads today\'s sales of own shop (as the app does)', async () => {
    const q = query(collection(db('m1'), 'cafes/c1/sales'),
      where('shopId', '==', 's1'), where('day', '==', '2026-11-13'));
    await assertSucceeds(getDocs(q));
  });
  test('cannot read another shop\'s sales', async () => {
    const f = db('m1');
    await assertFails(getDocs(query(collection(f, 'cafes/c1/sales'), where('shopId', '==', 's2'))));
    await assertFails(getDocs(collection(f, 'cafes/c1/sales')));
    await assertFails(getDoc(doc(f, 'cafes/c1/sales/sale_s2')));
  });
  test('can undo a sale of own shop, not of another shop', async () => {
    const f = db('m1');
    await assertSucceeds(deleteDoc(doc(f, 'cafes/c1/sales/sale_s1')));
    await assertFails(deleteDoc(doc(f, 'cafes/c1/sales/sale_s2')));
  });
  test('cannot edit a recorded sale', async () => {
    await assertFails(updateDoc(doc(db('m1'), 'cafes/c1/sales/sale_s1'), { total: 1 }));
  });
  test('can cancel and revive a sale of own shop, not of another shop', async () => {
    const f = db('m1');
    await assertSucceeds(updateDoc(doc(f, 'cafes/c1/sales/sale_s1'), { cancelled: true, cancelledAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(f, 'cafes/c1/sales/sale_s1'), { cancelled: false, cancelledAt: null }));
    await assertFails(updateDoc(doc(f, 'cafes/c1/sales/sale_s2'), { cancelled: true }));
  });
  test('owner cannot cancel sales (read-only view)', async () => {
    await assertFails(updateDoc(doc(db('owner1'), 'cafes/c1/sales/sale_s1'), { cancelled: true }));
  });
  test('cannot create a cafe that pretends to be owned by someone else', async () => {
    await assertFails(setDoc(doc(db('m1'), 'cafes/c9'), { name: 'X', ownerId: 'owner1' }));
  });
});
