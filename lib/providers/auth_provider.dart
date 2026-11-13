import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>(
    (ref) => ref.watch(authServiceProvider).authStateChanges());

/// Firestore profile (role etc.) of the signed-in user.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(authServiceProvider).profile(user.uid);
});
