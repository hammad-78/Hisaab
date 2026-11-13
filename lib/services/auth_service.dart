import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Live profile of the signed-in user (null if the doc doesn't exist yet).
  Stream<AppUser?> profile(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? AppUser.fromMap(uid, s.data()!) : null);

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  /// Owner self-registration. Managers are created later by the owner.
  Future<void> registerOwner({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = AppUser(
      uid: cred.user!.uid,
      name: name.trim(),
      email: email.trim(),
      role: UserRole.owner,
    );
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> signOut() => _auth.signOut();
}
