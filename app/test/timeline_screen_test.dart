import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/activity.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/timeline_repository.dart';
import 'package:squadquest/screens/timeline/timeline_screen.dart';

/// Fake repository injected via provider override (mobile-flutter patterns.md) —
/// lets the screen render real state without a live server.
class FakeTimelineRepository implements TimelineRepository {
  FakeTimelineRepository(this._page);
  final TimelinePage _page;
  @override
  Future<TimelinePage> friends({int limit = 50, String? before}) async => _page;
  @override
  Future<TimelinePage> squad(
    String squadId, {
    int limit = 50,
    String? before,
  }) async => _page;
}

Widget _harness(TimelinePage page) => ProviderScope(
  overrides: [
    timelineRepositoryProvider.overrideWithValue(FakeTimelineRepository(page)),
  ],
  child: const MaterialApp(home: TimelineScreen()),
);

void main() {
  testWidgets('renders activities from the timeline', (tester) async {
    await tester.pumpWidget(
      _harness(
        const TimelinePage(
          items: [
            Activity(
              id: 'a1',
              state: 'confirmed',
              captainName: 'Katie',
              activityTypeLabel: 'Paddleboarding',
              confirmedTime: 'Sun 2pm',
              confirmedLocation: 'Willamette',
            ),
            Activity(
              id: 'a2',
              state: 'idea',
              captainName: 'Mike',
              activityTypeLabel: 'Hiking',
              audienceSummary: 'all friends',
              inCount: 3,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timelineList')), findsOneWidget);
    expect(find.textContaining('Katie'), findsOneWidget);
    expect(find.textContaining('Hiking'), findsOneWidget);
    expect(find.text('3 in'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no activities', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const TimelinePage(items: [])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timelineEmpty')), findsOneWidget);
    expect(find.byKey(const Key('timelineList')), findsNothing);
  });
}
