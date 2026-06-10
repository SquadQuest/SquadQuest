import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/activity.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/topic_repository.dart';
import 'package:squadquest/screens/compose/compose_idea_screen.dart';

class FakeTopicRepository implements TopicRepository {
  @override
  Future<List<Topic>> list() async => const [
    Topic(id: 't1', label: 'Go on a Bike Ride'),
  ];
}

void main() {
  testWidgets(
    'composer pre-filled from a community event shows the event chip',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            topicRepositoryProvider.overrideWithValue(FakeTopicRepository()),
          ],
          child: const MaterialApp(
            home: ComposeIdeaScreen(
              broughtEvent: EventRef(
                id: 'e1',
                title: 'Cherry Blossoms Ride',
                time: 'Wed 6:30pm',
                communityName: 'Wednesday Night Rides',
                communityIcon: '🚲',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bring friends'), findsOneWidget); // app bar title
      expect(find.byKey(const Key('broughtEventChip')), findsOneWidget);
      expect(find.text('Cherry Blossoms Ride'), findsOneWidget);
      // a brought idea is still friends-scoped
      expect(find.byKey(const Key('composeDestination')), findsOneWidget);
      expect(find.textContaining('all your friends'), findsOneWidget);
    },
  );
}
