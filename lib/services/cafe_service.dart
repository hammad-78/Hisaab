import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/item.dart';
import '../models/shop.dart';
import '../models/waiter.dart';

class CafeService {
  CafeService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Creates the owner's cafe and links it to their profile.
  /// Two sequential writes: the profile rule checks the cafe already exists.
  Future<void> createCafe({
    required String ownerUid,
    required String name,
  }) async {
    final ref = _db.collection('cafes').doc();
    await ref.set({
      'name': name.trim(),
      'ownerId': ownerUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(ownerUid).update({'cafeId': ref.id});
  }

  Stream<String> cafeName(String cafeId) => _db
      .collection('cafes')
      .doc(cafeId)
      .snapshots()
      .map((s) => (s.data()?['name'] ?? '') as String);

  CollectionReference<Map<String, dynamic>> _col(String cafeId, String name) =>
      _db.collection('cafes').doc(cafeId).collection(name);

  // ---- menu items (shared by every shop in the cafe) ----
  Stream<List<Item>> items(String cafeId) => _col(
    cafeId,
    'items',
  ).orderBy('name').snapshots().map((q) => q.docs.map(Item.fromDoc).toList());

  Future<void> saveItem(
    String cafeId, {
    String? id,
    required String name,
    required num price,
  }) {
    final data = {'name': name.trim(), 'price': price};
    final col = _col(cafeId, 'items');
    return id == null
        ? col.add({...data, 'createdAt': FieldValue.serverTimestamp()})
        : col.doc(id).update(data);
  }

  Future<void> deleteItem(String cafeId, String id) =>
      _col(cafeId, 'items').doc(id).delete();

  // ---- waiters (each belongs to one shop) ----
  Stream<List<Waiter>> waiters(String cafeId) => _col(
    cafeId,
    'waiters',
  ).orderBy('name').snapshots().map((q) => q.docs.map(Waiter.fromDoc).toList());

  Future<void> saveWaiter(
    String cafeId, {
    String? id,
    required String name,
    required String shopId,
  }) {
    final data = {'name': name.trim(), 'shopId': shopId};
    final col = _col(cafeId, 'waiters');
    return id == null
        ? col.add({...data, 'createdAt': FieldValue.serverTimestamp()})
        : col.doc(id).update(data);
  }

  Future<void> deleteWaiter(String cafeId, String id) =>
      _col(cafeId, 'waiters').doc(id).delete();

  Stream<List<Shop>> shops(String cafeId) => _db
      .collection('cafes')
      .doc(cafeId)
      .collection('shops')
      .orderBy('createdAt')
      .snapshots()
      .map((q) => q.docs.map(Shop.fromDoc).toList());

  /// Creates a shop and its manager login.
  ///
  /// The Auth account is created on a temporary second Firebase app so the
  /// owner stays signed in. The Firestore docs are written with the owner's
  /// own session, which is what the security rules expect.
  Future<void> createShopWithManager({
    required String cafeId,
    required String shopName,
    required String managerName,
    required String managerEmail,
    required String managerPassword,
  }) async {
    final secondary = await Firebase.initializeApp(
      name: 'manager-creator-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);

    try {
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: managerEmail.trim(),
        password: managerPassword,
      );
      final managerUid = cred.user!.uid;

      try {
        final shopRef = _db
            .collection('cafes')
            .doc(cafeId)
            .collection('shops')
            .doc();
        final batch = _db.batch();
        batch.set(shopRef, {
          'name': shopName.trim(),
          'managerUid': managerUid,
          'managerName': managerName.trim(),
          'managerEmail': managerEmail.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(_db.collection('users').doc(managerUid), {
          'name': managerName.trim(),
          'email': managerEmail.trim(),
          'role': 'manager',
          'cafeId': cafeId,
          'shopId': shopRef.id,
        });
        await batch.commit();
      } catch (e) {
        // Don't leave an orphan login behind if the database write failed.
        await cred.user!.delete();
        rethrow;
      }
    } finally {
      await secondaryAuth.signOut();
      await secondary.delete();
    }
  }
}
