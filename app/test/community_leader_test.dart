import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:squadquest/models/community.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/community_repository.dart';
import 'package:squadquest/screens/communities/create_community_screen.dart';
import 'package:squadquest/screens/communities/create_event_screen.dart';
import 'package:squadquest/widgets/community_event_card.dart';

/// Records leader-tooling calls; returns canned values.
class FakeCommunityRepository implements CommunityRepository {
  String? createdName;
  String? createdEventCommunityId;
  String? createdEventTitle;

  @override
  Future<List<Community>> discover({String? search}) async => const [];
  @override
  Future<Community> follow(String communityId, {required bool follow}) async =>
      Community(id: communityId, name: '');
  @override
  Future<List<CommunityEvent>> events(String communityId) async => const [];
  @override
  Future<CommunityEvent> rsvp(
    String eventId, {
    required bool going,
    required bool public,
  }) async => CommunityEvent(id: eventId, title: '');

  @override
  Future<Community> create({
    required String name,
    String? tagline,
    String? icon,
    String? color,
  }) async {
    createdName = name;
    return Community(id: 'c-new', name: name, yourRole: 'leader');
  }

  @override
  Future<Community> update(
    String communityId, {
    String? name,
    String? tagline,
    String? icon,
    String? color,
  }) async => Community(id: communityId, name: name ?? '');

  @override
  Future<CommunityEvent> createEvent(
    String communityId, {
    required String title,
    String? time,
    String? recurrence,
    String? location,
  }) async {
    createdEventCommunityId = communityId;
    createdEventTitle = title;
    return CommunityEvent(id: 'e-new', title: title);
  }

  @override
  Future<CommunityEvent> updateEvent(
    String eventId, {
    String? title,
    String? time,
    String? recurrence,
    String? location,
  }) async => CommunityEvent(id: eventId, title: title ?? '');

  @override
  Future<void> deleteEvent(String eventId) async {}
}

/// Hosts [screen] at /target with a / home so go() / pop() resolve.
Widget _harness(Widget screen, FakeCommunityRepository fake) {
  final router = GoRouter(
    initialLocation: '/target',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(path: '/target', builder: (_, _) => screen),
    ],
  );
  return ProviderScope(
    overrides: [communityRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('create-community form posts the entered name', (tester) async {
    final fake = FakeCommunityRepository();
    await tester.pumpWidget(_harness(const CreateCommunityScreen(), fake));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('communityNameField')),
      'Wednesday Night Rides',
    );
    await tester.tap(find.byKey(const Key('communitySave')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.createdName, 'Wednesday Night Rides');
  });

  testWidgets('blank community name is rejected', (tester) async {
    final fake = FakeCommunityRepository();
    await tester.pumpWidget(_harness(const CreateCommunityScreen(), fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('communitySave')));
    await tester.pumpAndSettle();

    expect(fake.createdName, isNull);
    expect(find.text('Please enter a name.'), findsOneWidget);
  });

  testWidgets('post-event form posts the title to the community', (
    tester,
  ) async {
    final fake = FakeCommunityRepository();
    await tester.pumpWidget(
      _harness(const CreateEventScreen(communityId: 'c1'), fake),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('eventTitleField')),
      'Morning Paddle',
    );
    await tester.tap(find.byKey(const Key('eventSave')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.createdEventCommunityId, 'c1');
    expect(fake.createdEventTitle, 'Morning Paddle');
  });

  testWidgets('event card shows the leader menu only for a leader', (
    tester,
  ) async {
    const event = CommunityEvent(id: 'e1', title: 'Ride', communityName: 'WNR');

    Widget card(bool isLeader) => ProviderScope(
      overrides: [
        communityRepositoryProvider.overrideWithValue(
          FakeCommunityRepository(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CommunityEventCard(
            communityId: 'c1',
            event: event,
            isLeader: isLeader,
          ),
        ),
      ),
    );

    await tester.pumpWidget(card(false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event_menu_e1')), findsNothing);

    await tester.pumpWidget(card(true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event_menu_e1')), findsOneWidget);
  });
}
