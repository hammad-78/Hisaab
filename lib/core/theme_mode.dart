import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _key = 'app_theme_mode';
const _storage = FlutterSecureStorage();

/// Light by default; the owner can pick dark or follow the device.
Future<ThemeMode> loadSavedThemeMode() async {
  try {
    switch (await _storage.read(key: _key)) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
    }
  } catch (_) {}
  return ThemeMode.light;
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initial);

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ThemeMode.light),
);
