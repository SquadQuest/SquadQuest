import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/services/notifications.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/topic_memberships.dart';

final _sessionProviders = [
  profileProvider,
  rsvpsProvider,
  friendsProvider,
  topicMembershipsProvider,
];

// Main initialization provider that coordinates all service initialization
final appInitializationProvider = FutureProvider<void>((ref) async {
  log('Starting app initialization');

  // Initialize core services concurrently
  await Future.wait([
    ref.read(supabaseProvider.future),
    ref.read(firebaseProvider.future),
  ]);

  log('Core services initialized');

  // Load authentication state
  final session = ref.read(authControllerProvider);

  if (session != null) {
    await ref.read(sessionInitializationProvider.future);
  }
});

final sessionInitializationProvider = FutureProvider<void>((ref) async {
  log('Starting session initialization');

  // Pre-load initial data if a session exists
  await Future.wait([
    ref.read(profilesCacheProvider.notifier).initialized,
    ..._sessionProviders.map((provider) => ref.read(provider.future))
  ]);

  // Initialize notifications service
  ref.read(notificationsServiceProvider);

  log('Session initialized');
});

final sessionInvalidationProvider = Provider<Function>((ref) {
  return () {
    for (final provider in _sessionProviders) {
      ref.invalidate(provider);
    }
  };
});
