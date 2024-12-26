import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_screen/test_screen.dart';

import 'package:squadquest/theme.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/event_message.dart';

import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/controllers/location.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/chat.dart';

// Mock location controller
class MockLocationController extends LocationController {
  MockLocationController(super.ref);

  @override
  Future<void> startTracking([InstanceID? instanceId]) async {}

  @override
  Future<void> stopTracking([InstanceID? instanceId]) async {}
}

// Mock controller for RSVPs that returns empty list
class MockRsvpsController extends InstanceRsvpsController {
  @override
  Future<List<InstanceMember>> build(InstanceID arg) async {
    return [];
  }
}

// Mock controller for friends that returns empty list
class MockFriendsController extends FriendsController {
  @override
  Future<List<Friend>> build() async {
    return [];
  }
}

// Mock auth controller that returns mock user
class MockAuthController extends AuthController {
  @override
  Session? build() => Session(
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

// Base overrides used in all containers
final baseOverrides = [
  // Override auth to simulate logged out state
  authControllerProvider.overrideWith(() => MockAuthController()),

  // Override profiles cache
  profilesCacheProvider.overrideWith(() => MockProfilesCacheService()),

  // Override event details with mock data
  eventDetailsProvider(mockEvent.id!).overrideWith(
    (ref) => Future.value(mockEvent),
  ),

  // Override RSVPs with empty list
  rsvpsPerEventProvider.overrideWith(() => MockRsvpsController()),

  // Override friends with empty list
  friendsProvider.overrideWith(() => MockFriendsController()),

  // Override chat provider
  chatProvider.overrideWith(() => MockChatController()),

  // Override settings providers
  storybookModeProvider.overrideWith((ref) => true),
];

// Container with pinned message for testing bulletin
final mocksContainerWithPinnedMessage = ProviderContainer(
  overrides: [
    ...baseOverrides,
    latestPinnedMessageProvider.overrideWith(
      () => MockLatestPinnedMessageController(true),
    ),
  ],
);

// Container without pinned message
TestScreenConfig buildTestScreenConfig({ProviderContainer? container}) {
  return TestScreenConfig(
      locales: [
        'en'
      ],
      devices: {
        UITargetPlatform.webAndroid: [TestScreenDevice.forWeb(412, 915)],
        UITargetPlatform.webIos: [TestScreenDevice.forWeb(393, 852)],
        UITargetPlatform.android: [
          const TestScreenDevice(
            id: 'Pixel2',
            manufacturer: 'Google',
            name: 'Pixel 2',
            size: Size(1080, 1920),
            devicePixelRatio: 2.625,
          ),
          const TestScreenDevice(
            id: 'Pixel8Pro',
            manufacturer: 'Google',
            name: 'Pixel 8 Pros',
            size: Size(1344, 2992),
            devicePixelRatio: 3.0,
          ),
        ],
        UITargetPlatform.iOS: [
          const TestScreenDevice(
            id: 'iPhoneSE',
            manufacturer: 'Apple',
            name: 'iPhone SE 2022',
            size: Size(750, 1334),
            devicePixelRatio: 2.0,
          ),
          const TestScreenDevice(
            id: 'iPhone15Plus',
            manufacturer: 'Apple',
            name: 'iPhone 15 Plus',
            size: Size(1290, 2796),
            devicePixelRatio: 3.0,
          ),
        ],
      },
      wrapper: (WidgetTester tester, Widget screen) =>
          UncontrolledProviderScope(
            container: container ?? mocksContainer,
            child: MaterialApp(
              home: screen,
              theme: appThemeLight,
              darkTheme: appThemeDark,
              themeMode: ThemeMode.dark,
              debugShowCheckedModeBanner: false,
            ),
          ),
      onAfterCreate: (WidgetTester tester, Widget screen) async {
        await tester.pumpAndSettle();
      });
}

final mocksContainer = ProviderContainer(
  overrides: [
    ...baseOverrides,
    latestPinnedMessageProvider.overrideWith(
      () => MockLatestPinnedMessageController(false),
    ),
  ],
);
