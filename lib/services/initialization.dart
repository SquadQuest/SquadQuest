import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/services/notifications.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/topic_memberships.dart';

// Main initialization provider that coordinates all service initialization
final initializationProvider = FutureProvider<void>((ref) async {
  log('Starting app initialization');

  // Initialize core services concurrently
  await Future.wait([
    ref.watch(supabaseProvider.future),
    ref.watch(firebaseProvider.future),
  ]);

  // Pre-load initial data
  await Future.wait([
    ref.read(profilesCacheProvider.notifier).initialized,
    ref.read(profileProvider.future),
    ref.read(rsvpsProvider.future),
    ref.read(friendsProvider.future),
    ref.read(topicMembershipsProvider.future),
  ]);

  // Initialize notifications service
  ref.read(notificationsServiceProvider);

  log('Core services initialized');
});
