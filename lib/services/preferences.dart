import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:squadquest/logger.dart';

// Core provider that handles initialization
final preferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  logger.t('Initializing SharedPreferences');
  return await SharedPreferences.getInstance();
});

// For existing code that depends on sharedPreferencesProvider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  return ref.watch(preferencesProvider).requireValue;
});
