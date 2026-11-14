import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/manager/manager_home.dart';
import 'features/owner/owner_home.dart';
import 'firebase_options.dart';
import 'models/app_user.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final locale = await loadSavedLocale();
  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => LocaleNotifier(locale)),
      ],
      child: const HisaabApp(),
    ),
  );
}

class HisaabApp extends ConsumerWidget {
  const HisaabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      locale: locale,
      supportedLocales: const [englishLocale, urduLocale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'Hisaab',
      debugShowCheckedModeBanner: false,
      // Always light, even when the phone is in dark mode.
      // (A dark theme exists in core/theme.dart if it's wanted later.)
      theme: buildTheme(Brightness.light, urdu: locale.languageCode == 'ur'),
      themeMode: ThemeMode.light,
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
      error: (e, _) => _Message('${context.tr('Auth error')}: $e'),
      data: (firebaseUser) {
        if (firebaseUser == null) return const LoginScreen();

        final profile = ref.watch(appUserProvider);
        return profile.when(
          loading: () => const _Loading(),
          error: (e, _) => _Message('${context.tr('Could not load profile')}: $e'),
          data: (user) {
            if (user == null) {
              return const _Message(
                'Setting up your account…\nIf this stays, log out and try again.',
                showLogout: true,
              );
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
              Text(
                text.contains('Setting up') ? context.tr(text) : text,
                textAlign: TextAlign.center,
              ),
              if (showLogout)
                TextButton(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  child: Text(context.tr('Log out')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
