import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/activity.dart';
import 'package:squadquest/models/community.dart';
import 'package:squadquest/models/message.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/community_repository.dart';
import 'package:squadquest/repositories/message_repository.dart';
import 'package:squadquest/widgets/thread_drawer.dart';

/// Empty thread + no-op reply, so the drawer's conversation section settles.
class _FakeMessageRepository implements MessageRepository {
  @override
  Future<List<Message>> thread(String targetType, String targetId) async =>
      const [];
  @override
  Future<Message> reply(
    String targetType,
    String targetId,
    String body, {
    List<MessageAttachment> attachments = const [],
  }) async => const Message(id: 'm');
  @override
  Future<Message> postSquadMessage(
    String squadId,
    String body, {
    List<MessageAttachment> attachments = const [],
  }) async => const Message(id: 'm');
}

/// RSVP echo, unused reads.
class _FakeCommunityRepository implements CommunityRepository {
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
    String? photo,
  }) async => const Community(id: 'c', name: '');
  @override
  Future<Community> update(
    String communityId, {
    String? name,
    String? tagline,
    String? icon,
    String? color,
    String? photo,
  }) async => Community(id: communityId, name: '');
  @override
  Future<CommunityEvent> createEvent(
    String communityId, {
    required String title,
    String? time,
    String? recurrence,
    String? location,
  }) async => CommunityEvent(id: 'e', title: title);
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

Future<void> _pump(WidgetTester tester, ThreadTarget target) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        messageRepositoryProvider.overrideWithValue(_FakeMessageRepository()),
        communityRepositoryProvider.overrideWithValue(
          _FakeCommunityRepository(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showThreadDrawer(context, target: target),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('idea opens drawer with rich header + vote bar + audience hint', (
    tester,
  ) async {
    await _pump(
      tester,
      ThreadTarget.activity(
        const Activity(
          id: 'a1',
          state: 'idea',
          captainName: 'Katie',
          activityTypeLabel: 'Paddleboarding',
          audienceSummary: 'all friends',
          allowSuggestions: true,
          timeOptions: [ActivityOption(id: 'o1', label: 'Sat 7am', votes: 2)],
        ),
      ),
    );

    expect(find.byKey(const Key('threadDrawer')), findsOneWidget);
    expect(find.byKey(const Key('threadHeaderState')), findsOneWidget);
    expect(find.byKey(const Key('threadVoteBar')), findsOneWidget);
    expect(find.byKey(const Key('threadAudienceHint')), findsOneWidget);

    // Vote bar starts collapsed (leading chip), expands to options + suggest.
    expect(find.byKey(const Key('vote_o1')), findsNothing);
    await tester.tap(find.byKey(const Key('voteBarToggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vote_o1')), findsOneWidget);
    expect(find.byKey(const Key('suggestTime')), findsOneWidget);
  });

  testWidgets('squad message opens drawer with sender header, no vote bar', (
    tester,
  ) async {
    await _pump(
      tester,
      ThreadTarget.squadMessage(
        const Message(id: 'm1', senderName: 'Mike', body: 'yo'),
      ),
    );
    expect(find.byKey(const Key('threadDrawer')), findsOneWidget);
    expect(find.text('Mike'), findsOneWidget);
    expect(find.byKey(const Key('threadVoteBar')), findsNothing);
  });

  testWidgets('community event opens drawer with event header + RSVP', (
    tester,
  ) async {
    await _pump(
      tester,
      ThreadTarget.communityEvent(
        communityId: 'c1',
        event: const CommunityEvent(
          id: 'e1',
          title: 'Cherry Blossoms Ride',
          communityName: 'Wednesday Night Rides',
        ),
      ),
    );
    expect(find.byKey(const Key('threadDrawer')), findsOneWidget);
    expect(find.text('Cherry Blossoms Ride'), findsOneWidget);
    // RSVP control present; no vote bar for events.
    expect(find.byKey(const Key('going_toggle_e1')), findsOneWidget);
    expect(find.byKey(const Key('threadVoteBar')), findsNothing);
  });

  testWidgets('close button dismisses the drawer', (tester) async {
    await _pump(tester, ThreadTarget.squadMessage(const Message(id: 'm1')));
    expect(find.byKey(const Key('threadDrawer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('closeThreadDrawer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('threadDrawer')), findsNothing);
  });
}
