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
import '../repositories/upload_repository.dart';
import '../repositories/want_repository.dart';
import '../repositories/realtime_service.dart';
import '../models/want.dart';
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

final uploadRepositoryProvider = Provider<UploadRepository>(
  (ref) => ApiUploadRepository(apiClient: ref.watch(apiClientProvider)),
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

final wantRepositoryProvider = Provider<WantRepository>(
  (ref) => ApiWantRepository(apiClient: ref.watch(apiClientProvider)),
);

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final svc = RealtimeService(
    baseUrl: apiBaseUrl,
    tokenStore: ref.read(tokenStoreProvider),
  );
  ref.onDispose(svc.dispose);
  return svc;
});

/// Connects the SSE stream while signed in and turns each event into a Riverpod
/// cache invalidation (a nudge to refetch — never the source of truth). A dropped
/// stream just means staler-until-refresh; pull-to-refresh stays the fallback.
/// See specs/behaviors/realtime.md. Kept alive by a watch in the app shell.
final realtimeConnectionProvider = Provider<void>((ref) {
  final auth = ref.watch(authControllerProvider);
  final svc = ref.watch(realtimeServiceProvider);
  if (auth is! SignedIn) {
    svc.stop();
    return;
  }
  final sub = svc.events.listen((event) {
    switch (event.type) {
      case 'activity.created':
        ref.invalidate(friendsTimelineProvider);
        final sq = event.squadId;
        if (sq != null) ref.invalidate(squadTimelineProvider(sq));
      case 'message.created':
        final sq = event.squadId;
        if (sq != null) ref.invalidate(squadTimelineProvider(sq));
        final tType = event.threadTargetType;
        final tId = event.threadTargetId;
        if (tType != null && tId != null) {
          ref.invalidate(threadProvider('$tType:$tId'));
        }
    }
  });
  ref.onDispose(sub.cancel);
  svc.start();
});

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

/// The caller's own wants (specs/screens/wants.md).
final ownWantsProvider = FutureProvider<List<Want>>(
  (ref) => ref.watch(wantRepositoryProvider).listOwn(),
);

/// Wants the caller has been invited to.
final invitedWantsProvider = FutureProvider<List<Want>>(
  (ref) => ref.watch(wantRepositoryProvider).listInvited(),
);

/// The caller's ignored incoming items (specs/screens/ignored.md).
final ignoredItemsProvider = FutureProvider<List<IgnoredItem>>(
  (ref) => ref.watch(friendRepositoryProvider).ignored(),
);

/// The user's accepted friends (for squad member selection + the Friends screen).
final friendsProvider = FutureProvider<List<Friend>>(
  (ref) => ref.watch(friendRepositoryProvider).list(),
);

/// Pending connection requests (incoming + outgoing) for the Friends screen.
final friendRequestsProvider = FutureProvider<FriendRequests>(
  (ref) => ref.watch(friendRepositoryProvider).requests(),
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

/// The active community as the caller sees it (for `your_role` / leader controls),
/// looked up from the discover list. Null until loaded or if not present.
final activeCommunityProvider = Provider.family<Community?, String>((ref, id) {
  final list = ref.watch(communitiesProvider('')).value;
  if (list == null) return null;
  for (final c in list) {
    if (c.id == id) return c;
  }
  return null;
});
