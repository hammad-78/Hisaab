import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/login_screen.dart';
import 'features/manager/manager_home.dart';
import 'features/owner/owner_home.dart';
import 'firebase_options.dart';
import 'models/app_user.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: HisaabApp()));
}

class HisaabApp extends StatelessWidget {
  const HisaabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hisaab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Decides what to show: login, or the owner/manager home based on role.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const _Loading(),
      error: (e, _) => _Message('Auth error: $e'),
      data: (firebaseUser) {
        if (firebaseUser == null) return const LoginScreen();

        final profile = ref.watch(appUserProvider);
        return profile.when(
          loading: () => const _Loading(),
          error: (e, _) => _Message('Could not load profile: $e'),
          data: (user) {
            if (user == null) {
              return const _Message(
                  'Setting up your account…\nIf this stays, log out and try again.',
                  showLogout: true);
            }
            return user.role == UserRole.owner
                ? OwnerHome(user: user)
                : ManagerHome(user: user);
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Message extends ConsumerWidget {
  const _Message(this.text, {this.showLogout = false});
  final String text;
  final bool showLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              if (showLogout)
                TextButton(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  child: const Text('Log out'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
