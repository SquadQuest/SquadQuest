// import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final themeMode = prefs.getString('themeMode') ?? 'dark';
  return ThemeMode.values.firstWhere((e) => e.name == themeMode);
});

final settingsControllerProvider = Provider<SettingsController>((ref) {
  return SettingsController(ref);
});

class SettingsController {
  final Ref ref;

  SettingsController(this.ref) {
    _init();
  }

  void _init() {
    log('SettingsController._init');
    final prefs = ref.read(sharedPreferencesProvider);

    ref.listen(themeModeProvider, (_, themeMode) {
      log('SettingsController.themeModeProvider=${themeMode.name}');
      prefs.setString('themeMode', themeMode.name);
    });
  }
}
