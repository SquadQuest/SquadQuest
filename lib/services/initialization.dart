import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/services/notifications.dart';
import 'package:squadquest/logger.dart';

// Main initialization provider that coordinates all service initialization
final initializationProvider = FutureProvider<void>((ref) async {
  logger.t('Starting app initialization');

  // Initialize core services concurrently
  await Future.wait([
    ref.watch(supabaseProvider.future),
    ref.watch(firebaseProvider.future),
  ]);

  // Initialize notifications service
  ref.read(notificationsServiceProvider);

  logger.t('Core services initialized');
});
