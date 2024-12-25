import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/ui/event/event_screen.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/location.dart';
import 'package:squadquest/controllers/settings.dart';

const deviceSize = Size(428, 926);

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

// Mock auth controller that returns null (logged out state)
class MockAuthController extends AuthController {
  @override
  Session? build() => null;
}

void main() {
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
    title: 'Test Event',
    locationDescription: 'Test Location',
    notes: 'This is a test event description',
    startTimeMin: DateTime.now().add(const Duration(days: 1)),
    startTimeMax: DateTime.now().add(const Duration(days: 1, hours: 1)),
    // endTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
    createdAt: DateTime.now(),
    createdBy: mockUser,
  );

  Widget buildTestWidget() {
    final container = ProviderContainer(
      overrides: [
        // Override auth to simulate logged out state
        authControllerProvider.overrideWith(() => MockAuthController()),

        // Override event details with mock data
        eventDetailsProvider(mockEvent.id!).overrideWith(
          (ref) => Future.value(mockEvent),
        ),

        // Override RSVPs with empty list
        rsvpsPerEventProvider.overrideWith(() => MockRsvpsController()),

        // Override settings providers
        storybookModeProvider.overrideWith((ref) => true),
      ],
    );

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: EventScreen(eventId: mockEvent.id!),
      ),
    );
  }

  testWidgets('EventScreen displays event details', (tester) async {
    await tester.binding.setSurfaceSize(deviceSize);
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify event details are displayed
    expect(find.text(mockEvent.notes!), findsOneWidget);
    expect(find.text(mockEvent.createdBy!.displayName), findsOneWidget);
    expect(find.text(mockEvent.locationDescription), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('EventScreen golden test', (tester) async {
    await tester.binding.setSurfaceSize(deviceSize);
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await expectLater(
      find.byWidgetPredicate((widget) => widget is EventScreen),
      matchesGoldenFile('goldens/event_screen.png'),
    );

    await tester.binding.setSurfaceSize(null);
  });
}
