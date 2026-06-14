import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/activity.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/activity_repository.dart';
import 'package:squadquest/widgets/response_controls.dart';

/// Records set/clear and returns an activity reflecting the new response, so the
/// collapse/expand transitions can be driven without a server.
class _FakeActivityRepository implements ActivityRepository {
  String? lastSet;
  bool cleared = false;

  Activity _with(String? response) =>
      Activity(id: 'a1', state: 'idea', yourResponse: response);

  @override
  Future<Activity> setResponse(String activityId, String value) async {
    lastSet = value;
    return _with(value);
  }

  @override
  Future<Activity> clearResponse(String activityId) async {
    cleared = true;
    return _with(null);
  }

  // Unused here:
  @override
  Future<Activity> createIdea({
    String? activityTypeId,
    String? activityTypeLabel,
    bool allowSuggestions = false,
    List<String> timeOptions = const [],
    List<String> locationOptions = const [],
    String? squadId,
    String? communityEventId,
  }) async => throw UnimplementedError();
  @override
  Future<Activity> vote(
    String activityId,
    String optionId, {
    required bool voted,
  }) async => throw UnimplementedError();
  @override
  Future<Activity> addOption(
    String activityId,
    String kind,
    String label,
  ) async => throw UnimplementedError();
  @override
  Future<Activity> confirm(
    String activityId, {
    String? timeOptionId,
    String? locationOptionId,
  }) async => throw UnimplementedError();
}

Future<_FakeActivityRepository> _pump(WidgetTester tester, Activity a) async {
  final repo = _FakeActivityRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activityRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(body: ResponseControls(activity: a)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('unresponded shows all three options, no chip', (tester) async {
    await _pump(tester, const Activity(id: 'a1', state: 'idea'));
    expect(find.byKey(const Key('response_in')), findsOneWidget);
    expect(find.byKey(const Key('response_interested')), findsOneWidget);
    expect(find.byKey(const Key('response_next_time')), findsOneWidget);
    expect(find.byKey(const Key('responseChip')), findsNothing);
  });

  testWidgets('choosing a response collapses to a chip', (tester) async {
    final repo = await _pump(tester, const Activity(id: 'a1', state: 'idea'));
    await tester.tap(find.byKey(const Key('response_in')));
    await tester.pumpAndSettle();
    expect(repo.lastSet, 'in');
    // Row collapsed to a single chip showing the choice.
    expect(find.byKey(const Key('responseChip')), findsOneWidget);
    expect(find.byKey(const Key('response_in')), findsNothing);
  });

  testWidgets('already-responded starts collapsed; chip re-expands', (
    tester,
  ) async {
    await _pump(
      tester,
      const Activity(id: 'a1', state: 'idea', yourResponse: 'interested'),
    );
    // Seeded collapsed.
    expect(find.byKey(const Key('responseChip')), findsOneWidget);
    expect(find.byKey(const Key('response_in')), findsNothing);

    // Tap the chip → expands to the full row with the current choice selected.
    await tester.tap(find.byKey(const Key('responseChip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('response_interested')), findsOneWidget);
    expect(find.byKey(const Key('response_in')), findsOneWidget);
  });
}
