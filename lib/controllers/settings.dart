// import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.dark;
});

class SettingsController extends Notifier<void> {
  @override
  void build() {
    // no-op
  }
}
