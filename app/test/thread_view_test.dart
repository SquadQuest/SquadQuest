import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/message.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/message_repository.dart';
import 'package:squadquest/widgets/thread_view.dart';

class FakeMessageRepository implements MessageRepository {
  FakeMessageRepository(this._messages);
  final List<Message> _messages;

  @override
  Future<List<Message>> thread(String targetType, String targetId) async =>
      _messages;
  @override
  Future<Message> reply(String t, String id, String body) async =>
      Message(id: 'new', body: body);
  @override
  Future<Message> postSquadMessage(String squadId, String body) async =>
      Message(id: 'new', body: body);
}

void main() {
  testWidgets('thread renders replies (chronological) + a reply input', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageRepositoryProvider.overrideWithValue(
            // endpoint returns newest-first; view should show oldest first
            FakeMessageRepository(const [
              Message(id: 'm2', senderName: 'Mike', body: 'second'),
              Message(id: 'm1', senderName: 'Katie', body: 'first'),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ThreadView(targetType: 'activity', targetId: 'a1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('threadMessages')), findsOneWidget);
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.byKey(const Key('threadReplyField')), findsOneWidget);
    expect(find.byKey(const Key('threadReplySend')), findsOneWidget);
  });

  testWidgets('empty thread shows a start-the-conversation hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageRepositoryProvider.overrideWithValue(
            FakeMessageRepository(const []),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ThreadView(targetType: 'message', targetId: 'x'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No replies yet'), findsOneWidget);
  });
}
