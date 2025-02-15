import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/services/notifications.dart';

// Main initialization provider that coordinates all service initialization
final initializationProvider = FutureProvider<void>((ref) async {
  log('Starting app initialization');

  // Initialize core services concurrently
  await Future.wait([
    ref.watch(supabaseProvider.future),
    ref.watch(firebaseProvider.future),
  ]);

  // Load initial data
  await Future.wait([
    ref.watch(profilesCacheProvider.notifier).initialized,
  ]);

  // Initialize notifications service
  ref.read(notificationsServiceProvider);

  log('Core services initialized');
});
