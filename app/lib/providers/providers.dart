import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/community.dart';
import '../models/friend.dart';
import '../models/message.dart';
import '../models/squad.dart';
import '../models/topic.dart';
import '../repositories/activity_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/community_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/message_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/squad_repository.dart';
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

final squadRepositoryProvider = Provider<SquadRepository>(
  (ref) => ApiSquadRepository(apiClient: ref.watch(apiClientProvider)),
);

final friendRepositoryProvider = Provider<FriendRepository>(
  (ref) => ApiFriendRepository(apiClient: ref.watch(apiClientProvider)),
);

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => ApiMessageRepository(apiClient: ref.watch(apiClientProvider)),
);

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => ApiCommunityRepository(apiClient: ref.watch(apiClientProvider)),
);

/// The My Friends timeline (specs/screens/friends-timeline.md).
final friendsTimelineProvider = FutureProvider<TimelinePage>(
  (ref) => ref.watch(timelineRepositoryProvider).friends(),
);

/// A squad's heterogeneous timeline (activities + messages), keyed by squad id.
final squadTimelineProvider = FutureProvider.family<SquadFeedPage, String>(
  (ref, squadId) => ref.watch(timelineRepositoryProvider).squadFeed(squadId),
);

/// A thread's messages, keyed by `targetType:targetId`.
final threadProvider = FutureProvider.family<List<Message>, String>((ref, key) {
  final i = key.indexOf(':');
  return ref
      .watch(messageRepositoryProvider)
      .thread(key.substring(0, i), key.substring(i + 1));
});

/// The user's squads (for the context selector).
final squadsProvider = FutureProvider<List<Squad>>(
  (ref) => ref.watch(squadRepositoryProvider).list(),
);

/// Activity types for the compose-idea form (specs/api/ideas-activities.md).
final topicsProvider = FutureProvider<List<Topic>>(
  (ref) => ref.watch(topicRepositoryProvider).list(),
);

/// The user's accepted friends (for squad member selection).
final friendsProvider = FutureProvider<List<Friend>>(
  (ref) => ref.watch(friendRepositoryProvider).list(),
);

/// Communities to discover (all, with you_follow), optional search query.
final communitiesProvider = FutureProvider.family<List<Community>, String>((
  ref,
  search,
) {
  return ref
      .watch(communityRepositoryProvider)
      .discover(search: search.isEmpty ? null : search);
});

/// A community's events, keyed by community id.
final communityEventsProvider =
    FutureProvider.family<List<CommunityEvent>, String>((ref, communityId) {
      return ref.watch(communityRepositoryProvider).events(communityId);
    });
