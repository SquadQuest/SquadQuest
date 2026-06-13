import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/topic_repository.dart';
import 'package:squadquest/widgets/topic_picker.dart';

class _FakeTopicRepository implements TopicRepository {
  @override
  Future<List<Topic>> list() async => const [
    Topic(id: 't1', label: 'Go Hiking', kind: 'official'),
    Topic(id: 't2', label: 'Disc Golf', kind: 'community'),
  ];
}

Widget _host(ValueChanged<TopicSelection> onChanged) => ProviderScope(
  overrides: [
    topicRepositoryProvider.overrideWithValue(_FakeTopicRepository()),
  ],
  child: MaterialApp(
    home: Scaffold(body: TopicPicker(selection: null, onChanged: onChanged)),
  ),
);

void main() {
  testWidgets('picks an existing topic', (tester) async {
    TopicSelection? picked;
    await tester.pumpWidget(_host((s) => picked = s));
    await tester.tap(find.byKey(const Key('topicPicker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('topicOption_t1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('topicOption_t1')));
    await tester.pumpAndSettle();

    expect(picked?.topic?.id, 't1');
    expect(picked?.label, isNull);
  });

  testWidgets('offers "create" for an unmatched query → newLabel selection', (
    tester,
  ) async {
    TopicSelection? picked;
    await tester.pumpWidget(_host((s) => picked = s));
    await tester.tap(find.byKey(const Key('topicPicker')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('topicSearchField')), 'Kubb');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('createTopicOption')), findsOneWidget);
    await tester.tap(find.byKey(const Key('createTopicOption')));
    await tester.pumpAndSettle();

    expect(picked?.label, 'Kubb');
    expect(picked?.topic, isNull);
  });

  testWidgets('no "create" option when the query exactly matches a topic', (
    tester,
  ) async {
    await tester.pumpWidget(_host((_) {}));
    await tester.tap(find.byKey(const Key('topicPicker')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('topicSearchField')),
      'Go Hiking',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('createTopicOption')), findsNothing);
    expect(find.byKey(const Key('topicOption_t1')), findsOneWidget);
  });
}
