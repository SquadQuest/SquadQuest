import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/friend_repository.dart';
import 'package:squadquest/screens/ignored/ignored_screen.dart';

/// Minimal fake serving the ignored list + recording un-ignore.
class _FakeFriendRepository implements FriendRepository {
  _FakeFriendRepository(this.items);
  final List<IgnoredItem> items;
  String? unignoredId;

  @override
  Future<List<IgnoredItem>> ignored() async => items;
  @override
  Future<void> unignore(String requestId) async {
    unignoredId = requestId;
  }

  @override
  Future<List<Friend>> list() async => const [];
  @override
  Future<FriendRequests> requests() async => const FriendRequests();
  @override
  Future<String> sendRequest(String phone) async => 'requested';
  @override
  Future<void> accept(String requestId) async {}
  @override
  Future<void> ignore(String requestId) async {}
}

Widget _app(_FakeFriendRepository fake) => ProviderScope(
  overrides: [friendRepositoryProvider.overrideWithValue(fake)],
  child: const MaterialApp(home: IgnoredScreen()),
);

void main() {
  testWidgets('empty shows "Nothing ignored"', (tester) async {
    await tester.pumpWidget(_app(_FakeFriendRepository(const [])));
    await tester.pumpAndSettle();
    expect(find.text('Nothing ignored'), findsOneWidget);
  });

  testWidgets('lists an ignored friend request and un-ignores it', (
    tester,
  ) async {
    final fake = _FakeFriendRepository(const [
      IgnoredItem(
        id: 'r1',
        type: 'friend_request',
        profile: Friend(id: 'p1', firstName: 'Sam'),
      ),
    ]);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    expect(find.textContaining('Friend request from Sam'), findsOneWidget);

    await tester.tap(find.byKey(const Key('unignore_r1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.unignoredId, 'r1');
  });
}
