import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/activity.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/activity_repository.dart';
import 'package:squadquest/screens/activity/activity_detail_screen.dart';

/// Fake that echoes a canned updated activity for each action, so the screen's
/// state-swap + control wiring can be tested without a server.
class FakeActivityRepository implements ActivityRepository {
  FakeActivityRepository(this.result);
  Activity result;
  String? addedKind;
  String? addedLabel;

  @override
  Future<Activity> createIdea({
    String? activityTypeId,
    String? activityTypeLabel,
    bool allowSuggestions = false,
    List<String> timeOptions = const [],
    List<String> locationOptions = const [],
    String? squadId,
    String? communityEventId,
  }) async => result;

  @override
  Future<Activity> setResponse(String activityId, String value) async => result;
  @override
  Future<Activity> clearResponse(String activityId) async => result;
  @override
  Future<Activity> vote(
    String activityId,
    String optionId, {
    required bool voted,
  }) async => result;
  @override
  Future<Activity> addOption(
    String activityId,
    String kind,
    String label,
  ) async {
    addedKind = kind;
    addedLabel = label;
    return result;
  }

  @override
  Future<Activity> confirm(
    String activityId, {
    String? timeOptionId,
    String? locationOptionId,
  }) async => result;
}

void main() {
  testWidgets('renders options + response counts; vote calls the repo', (
    tester,
  ) async {
    const seed = Activity(
      id: 'a1',
      state: 'idea',
      captainName: 'Katie',
      activityTypeLabel: 'Paddleboarding',
      audienceSummary: 'all friends',
      inCount: 2,
      interestedCount: 1,
      timeOptions: [ActivityOption(id: 'o1', label: 'Sat 7am', votes: 1)],
    );
    final voted = const Activity(
      id: 'a1',
      state: 'idea',
      captainName: 'Katie',
      activityTypeLabel: 'Paddleboarding',
      inCount: 2,
      interestedCount: 1,
      timeOptions: [
        ActivityOption(id: 'o1', label: 'Sat 7am', votes: 2, youVoted: true),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository(voted),
          ),
        ],
        child: const MaterialApp(home: ActivityDetailScreen(activity: seed)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activityDetail')), findsOneWidget);
    expect(find.text('2 in · 1 interested'), findsOneWidget);
    expect(find.text('Sat 7am'), findsOneWidget);
    expect(find.text('1 vote'), findsOneWidget);

    // Tap the vote button → repo returns the "voted" activity → state swaps.
    await tester.tap(find.byIcon(Icons.thumb_up_outlined));
    await tester.pumpAndSettle();
    expect(find.text('2 votes'), findsOneWidget);
  });

  testWidgets('suggest-an-option appears when allowed and calls addOption', (
    tester,
  ) async {
    const seed = Activity(
      id: 'a1',
      state: 'idea',
      captainName: 'Katie',
      activityTypeLabel: 'Paddleboarding',
      allowSuggestions: true,
    );
    final repo = FakeActivityRepository(seed);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [activityRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ActivityDetailScreen(activity: seed)),
      ),
    );
    await tester.pumpAndSettle();

    // Both suggest affordances show even with no options yet.
    expect(find.byKey(const Key('suggestTime')), findsOneWidget);
    expect(find.byKey(const Key('suggestLocation')), findsOneWidget);

    // Suggest a time → dialog → submit → addOption('time', label).
    await tester.tap(find.byKey(const Key('suggestTime')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('suggestOptionField')),
      'Sunday brunch',
    );
    await tester.tap(find.text('Suggest'));
    await tester.pumpAndSettle();
    expect(repo.addedKind, 'time');
    expect(repo.addedLabel, 'Sunday brunch');
  });

  testWidgets('shows fallback when opened without an activity', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository(const Activity(id: 'x', state: 'idea')),
          ),
        ],
        child: const MaterialApp(home: ActivityDetailScreen(activity: null)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detailUnavailable')), findsOneWidget);
  });
}
