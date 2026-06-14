import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/community.dart';
import 'package:squadquest/models/message.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/message_repository.dart';
import 'package:squadquest/widgets/community_event_card.dart';

void main() {
  testWidgets('event card shows headcount + face-pile + RSVP toggles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CommunityEventCard(
              communityId: 'c1',
              event: CommunityEvent(
                id: 'e1',
                title: 'Cherry Blossoms Ride',
                communityName: 'Wednesday Night Rides',
                recurrence: 'Every other Wed',
                time: 'Wed 6:30pm',
                location: 'Clark Park',
                goingCount: 64,
                publicGoing: ['Maya', 'Jordan', 'Sam'],
                youGoing: true,
                youPublic: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cherry Blossoms Ride'), findsOneWidget);
    // anonymous headcount + opt-in face-pile (truncated)
    expect(find.textContaining('64 going'), findsOneWidget);
    expect(find.textContaining('Maya, Jordan +1 publicly'), findsOneWidget);
    // RSVP gradient toggles, reflecting state
    expect(find.byKey(const Key('going_toggle_e1')), findsOneWidget);
    expect(find.byKey(const Key('public_toggle_e1')), findsOneWidget);
  });

  testWidgets('tapping the card opens the event thread drawer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageRepositoryProvider.overrideWithValue(_FakeMessageRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CommunityEventCard(
              communityId: 'c1',
              event: CommunityEvent(id: 'e1', title: 'Cherry Blossoms Ride'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openEventThread_e1')));
    await tester.pumpAndSettle();
    // The drawer slides in with the event as its header.
    expect(find.byKey(const Key('threadDrawer')), findsOneWidget);
  });
}

/// Empty thread so the drawer's conversation section settles.
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
