import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/topic.dart';
import '../repositories/activity_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/timeline_repository.dart';
import '../repositories/token_store.dart';
import '../repositories/topic_repository.dart';
import 'auth_controller.dart';

/// Dependency-injection providers. Repositories expose abstract types so tests
/// and storybook can override them with fakes (see mobile-flutter patterns.md).

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: apiBaseUrl,
    tokenStore: ref.read(tokenStoreProvider),
    clientHeader: clientHeader,
    onAuthFailure: () async =>
        ref.read(authControllerProvider.notifier).forceSignOut(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokens: ref.watch(tokenStoreProvider),
  ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ApiProfileRepository(apiClient: ref.watch(apiClientProvider)),
);

final timelineRepositoryProvider = Provider<TimelineRepository>(
  (ref) => ApiTimelineRepository(apiClient: ref.watch(apiClientProvider)),
);

final topicRepositoryProvider = Provider<TopicRepository>(
  (ref) => ApiTopicRepository(apiClient: ref.watch(apiClientProvider)),
);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ApiActivityRepository(apiClient: ref.watch(apiClientProvider)),
);

/// The My Friends timeline (specs/screens/friends-timeline.md).
final friendsTimelineProvider = FutureProvider<TimelinePage>(
  (ref) => ref.watch(timelineRepositoryProvider).friends(),
);

/// Activity types for the compose-idea form (specs/api/ideas-activities.md).
final topicsProvider = FutureProvider<List<Topic>>(
  (ref) => ref.watch(topicRepositoryProvider).list(),
);
