import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/friend.dart';

import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/controllers/location.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/controllers/rsvps.dart';

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

// Mock profiles cache that returns mock user
class MockProfilesCacheService extends ProfilesCacheService {
  @override
  ProfilesCache build() => {mockUser.id: mockUser};
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

final mocksContainer = ProviderContainer(
  overrides: [
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

    // Override settings providers
    storybookModeProvider.overrideWith((ref) => true),
  ],
);
