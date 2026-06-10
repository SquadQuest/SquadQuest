import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/community.dart';
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
}
