// import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// TODO: when adding future settings, use e.g. setBool instead of setString for everything

// Import preferences provider from services
import 'package:squadquest/services/preferences.dart';

final settingsControllerProvider = Provider<SettingsController>((ref) {
  return SettingsController(ref);
});

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final themeMode = prefs.getString('themeMode') ?? 'dark';
  return ThemeMode.values.firstWhere((e) => e.name == themeMode);
});

final developerModeProvider = StateProvider<bool>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final developerMode = prefs.getString('developerMode') ?? 'false';
  return developerMode == 'true';
});

final storybookModeProvider = StateProvider<bool>((ref) => false);

final locationSharingEnabledProvider = StateProvider<bool?>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final locationSharingEnabled = prefs.getString('locationSharingEnabled');
  return locationSharingEnabled == null
      ? null
      : locationSharingEnabled == 'true';
});

final calendarWritingEnabledProvider = StateProvider<bool>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final calendarWritingEnabled =
      prefs.getString('calendarWritingEnabled') ?? 'false';
  return calendarWritingEnabled == 'true';
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
      log('SettingsController.themeMode=${themeMode.name}');
      prefs.setString('themeMode', themeMode.name);
    });

    ref.listen(developerModeProvider, (_, developerMode) {
      log('SettingsController.developerMode=$developerMode');
      prefs.setString('developerMode', developerMode.toString());
    });

    ref.listen(locationSharingEnabledProvider, (_, locationSharingEnabled) {
      log('SettingsController.locationSharingEnabled=$locationSharingEnabled');
      prefs.setString(
          'locationSharingEnabled', locationSharingEnabled.toString());
    });

    ref.listen(calendarWritingEnabledProvider, (_, calendarWritingEnabled) {
      log('SettingsController.calendarWritingEnabled=$calendarWritingEnabled');
      prefs.setString(
          'calendarWritingEnabled', calendarWritingEnabled.toString());
    });
  }

  Future<void> clear() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.clear();
  }
}
