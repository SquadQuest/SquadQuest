import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:squadquest/logger.dart';

// Core provider for SharedPreferences
final preferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  log('Initializing SharedPreferences');
  return await SharedPreferences.getInstance();
});
