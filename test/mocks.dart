import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:squadquest/theme.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/app_version.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/event_message.dart';

import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/controllers/topics.dart';
import 'package:squadquest/controllers/topic_subscriptions.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/controllers/location.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/chat.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/controllers/app_versions.dart';
import 'package:squadquest/screens/splash.dart';

class MockSupabase extends Fake implements SupabaseClient {
  @override
  get auth => MockGotrue();
}

Stream<AuthState> mockAuthStateChangeStream() async* {
  yield AuthState(
    AuthChangeEvent.initialSession,
    mockSession,
  );
}

class MockGotrue extends Fake implements GoTrueClient {
  @override
  Session? get currentSession => mockSession;
  @override
  User? get currentUser => mockSession.user;

  @override
  Stream<AuthState> get onAuthStateChange => mockAuthStateChangeStream();
}

// Mock profile controller
class MockProfileController extends ProfileController {
  @override
  Future<UserProfile> build() async {
    return mockUser;
  }
}

final mockAppVersion = AppVersion(
  build: 0,
  version: '0.0',
  released: DateTime(2024, 1, 1),
  supported: true,
  notices: null,
  news: null,
  availability: [],
);

// Mock app versions controller
class MockAppVersionsController extends AppVersionsController {
  @override
  Future<List<AppVersion>> build() async {
    return [mockAppVersion];
  }

  @override
  Future<void> showUpdateAlertIfAvailable() async {}
}

// Mock Firebase messaging service
class MockFirebaseMessagingService extends FirebaseMessagingService {
  MockFirebaseMessagingService(super.ref);

  @override
  Future<void> requestPermissions() async {}
}

// Mock location controller
class MockLocationController extends LocationController {
  MockLocationController(super.ref);

  @override
  void init() async {}

  @override
  Future<void> startTracking([InstanceID? instanceId]) async {
    tracking = true;
  }

  @override
  Future<void> stopTracking([InstanceID? instanceId]) async {
    tracking = false;
  }
}

// Mock controllers for topics
class MockTopicsController extends TopicsController {
  @override
  Future<List<Topic>> build() async {
    return [];
  }
}

class MockTopicSubscriptionsController extends TopicSubscriptionsController {
  final bool hasSubscriptions;

  MockTopicSubscriptionsController([this.hasSubscriptions = true]);

  @override
  Future<List<TopicID>> build() async {
    return hasSubscriptions ? ['test-topic-1'] : [];
  }
}

// Mock controller for instances that returns test event
class MockInstancesController extends InstancesController {
  final bool hasEvents;

  MockInstancesController([this.hasEvents = true]);

  @override
  Future<List<Instance>> build() async {
    return hasEvents ? [mockEvent] : [];
  }
}

// Mock controller for RSVPs per event
final rsvpMockStateProvider =
    Provider<Map<String, List<InstanceMember>>>((ref) {
  throw UnimplementedError();
});

class MockInstanceRsvpsController extends InstanceRsvpsController {
  @override
  Future<List<InstanceMember>> build(InstanceID eventId) async {
    final instanceRsvps = ref.read(rsvpMockStateProvider);
    final rsvps = instanceRsvps[eventId] ?? [];
    return rsvps;
  }
}

// Mock controller for RSVPs
class MockRsvpsController extends RsvpsController {
  @override
  Future<List<InstanceMember>> build() async {
    return [];
  }

  @override
  Future<InstanceMember?> save(Instance instance, InstanceMemberStatus? status,
      {String? note}) async {
    final instanceRsvps = ref.read(rsvpMockStateProvider);

    if (status == null) {
      instanceRsvps[instance.id!] = [];
      ref.invalidate(rsvpsPerEventProvider(instance.id!));
      return null;
    }

    final rsvp = InstanceMember(
      instance: instance,
      memberId: mockUser.id,
      status: status,
    );

    instanceRsvps[instance.id!] = [rsvp];
    ref.invalidate(rsvpsPerEventProvider(instance.id!));
    return rsvp;
  }
}

// Mock controller for friends
class MockFriendsController extends FriendsController {
  final bool hasPendingRequests;

  MockFriendsController([this.hasPendingRequests = false]);

  @override
  Future<List<Friend>> build() async {
    if (!hasPendingRequests) return [];

    return [
      Friend(
        id: 'test-friend-1',
        status: FriendStatus.requested,
        requesterId: mockUser2.id,
        requester: mockUser2,
        requesteeId: mockUser.id,
        requestee: mockUser,
        createdAt: DateTime.now(),
      ),
    ];
  }
}

// Mock auth controller that returns mock user
class MockAuthController extends AuthController {
  @override
  Session? build() => mockSession;
}

// Mock profiles cache that returns mock users
class MockProfilesCacheService extends ProfilesCacheService {
  @override
  ProfilesCache build() => {
        mockUser.id: mockUser,
        mockUser2.id: mockUser2,
      };
}

// Mock chat controller
class MockChatController extends ChatController {
  @override
  Future<List<EventMessage>> build(InstanceID arg) async {
    return mockMessages;
  }

  @override
  Future<void> updateLastSeen(DateTime timestamp) async {}
}

// Mock latest pinned message controller
class MockLatestPinnedMessageController extends LatestPinnedMessageController {
  final bool hasPinnedMessage;

  MockLatestPinnedMessageController(this.hasPinnedMessage);

  @override
  Future<EventMessage?> build(InstanceID arg) async {
    if (!hasPinnedMessage) return null;
    return mockMessages.lastWhere((m) => m.pinned);
  }
}

final mockSession = Session(
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    tokenType: 'test-token',
    user: User(
      id: mockUser.id,
      appMetadata: {},
      userMetadata: {},
      aud: 'test-aud',
      createdAt: '2024-01-01 12:00:00',
    ));

final mockUser = UserProfile(
  id: 'test-user-1',
  firstName: 'Test',
  lastName: 'User',
  phone: null,
  fcmToken: null,
  fcmTokenUpdatedAt: null,
  fcmTokenAppBuild: null,
  photo: null,
  enabledNotifications: {},
);

final mockUser2 = UserProfile(
  id: 'test-user-2',
  firstName: 'Another',
  lastName: 'User',
  phone: null,
  fcmToken: null,
  fcmTokenUpdatedAt: null,
  fcmTokenAppBuild: null,
  photo: null,
  enabledNotifications: {},
);

final mockMessages = [
  // Regular chat messages
  EventMessage(
    id: 'msg-1',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    createdBy: mockUser2,
    event: mockEvent.id!,
    content: 'Looking forward to this!',
    pinned: false,
  ),
  EventMessage(
    id: 'msg-2',
    createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
    createdBy: mockUser,
    event: mockEvent.id!,
    content: 'Me too! Bringing snacks.',
    pinned: false,
  ),
  // Pinned messages
  EventMessage(
    id: 'msg-3',
    createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
    createdBy: mockUser,
    event: mockEvent.id!,
    content:
        'IMPORTANT: We\'ll be in the back room, look for the SquadQuest sign!',
    pinned: true,
  ),
  EventMessage(
    id: 'msg-4',
    createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
    createdBy: mockUser2,
    event: mockEvent.id!,
    content: 'Just got here, parking is available on the street',
    pinned: false,
  ),
  // Pinned messages
  EventMessage(
    id: 'msg-5',
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    createdBy: mockUser,
    event: mockEvent.id!,
    content: 'UPDATE: Building code is 1234#',
    pinned: true,
  ),
];

final mockEvent = Instance(
  id: 'test-event-1',
  status: InstanceStatus.live,
  visibility: InstanceVisibility.public,
  title: 'New Years Eve Celebration',
  locationDescription: 'Awesome Venue',
  notes: 'Bring in the new year with your favorite friends!\n\n'
      'BYO drinks and snack. We\'ll start at 10pm and kick everyone out by 2am. The building code is 1234 and then go up to the 4th floor.\n\n'
      'Don\'t drink and drive! Have your ride home planned.',
  startTimeMin: DateTime(2024, 12, 31, 22),
  startTimeMax: DateTime(2024, 12, 31, 23, 59, 59),
  endTime: DateTime(2025, 1, 1, 2, 0, 0),
  link: Uri.parse(
      'https://www.etix.com/ticket/p/43349598/zoo-years-eve-with-too-many-zooz-philadelphia-music-hall-at-world-cafe-live'),
  topic: Topic(id: 'test-topic-1', name: 'party.house'),
  createdAt: DateTime(2024, 11, 1, 12),
  createdBy: mockUser,
  createdById: mockUser.id,
);

// Builder for mock environments
ProviderScope buildMockEnvironment(Widget screen, {String? scenario}) =>
    ProviderScope(
      overrides: [
        // Override auth to simulate logged out state
        authControllerProvider.overrideWith(() => MockAuthController()),

        // Override profiles cache
        profilesCacheProvider.overrideWith(() => MockProfilesCacheService()),

        // Override topics
        topicsProvider.overrideWith(() => MockTopicsController()),
        topicSubscriptionsProvider.overrideWith(
          () => MockTopicSubscriptionsController(
            scenario != 'no-subscriptions',
          ),
        ),

        // Override instances with mock data
        instancesProvider.overrideWith(() => MockInstancesController(
              scenario != 'no-subscriptions',
            )),
        eventDetailsProvider(mockEvent.id!).overrideWith(
          (ref) => Future.value(mockEvent),
        ),

        // Override RSVPs
        rsvpMockStateProvider
            .overrideWith((ref) => <String, List<InstanceMember>>{}),
        rsvpsProvider.overrideWith(() => MockRsvpsController()),
        rsvpsPerEventProvider.overrideWith(() => MockInstanceRsvpsController()),

        // Override friends
        friendsProvider.overrideWith(
          () => MockFriendsController(
            scenario == 'friend-requests',
          ),
        ),

        // Override chat provider
        chatProvider.overrideWith(() => MockChatController()),

        // Override location controller
        locationControllerProvider
            .overrideWith((ref) => MockLocationController(ref)),

        // Override settings providers
        themeModeProvider.overrideWith((ref) => ThemeMode.dark),
        developerModeProvider.overrideWith((ref) => false),
        splashCompleteProvider.overrideWith((ref) => true),

        // Override Firebase messaging
        firebaseMessagingServiceProvider
            .overrideWith((ref) => MockFirebaseMessagingService(ref)),
        firebaseMessagingStreamProvider.overrideWith((ref) => Stream.empty()),

        // Override app initialization
        profileProvider.overrideWith(() => MockProfileController()),
        appVersionsProvider.overrideWith(() => MockAppVersionsController()),

        // Override Supabase
        supabaseClientProvider.overrideWithValue(MockSupabase()),

        // scenarios
        ...switch (scenario) {
          'pinned-message' => [
              latestPinnedMessageProvider.overrideWith(
                () => MockLatestPinnedMessageController(true),
              ),
            ],
          _ => [
              latestPinnedMessageProvider.overrideWith(
                () => MockLatestPinnedMessageController(false),
              ),
            ]
        }
      ],
      child: MaterialApp(
        home: screen,
        theme: appThemeLight,
        darkTheme: appThemeDark,
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
      ),
    );
