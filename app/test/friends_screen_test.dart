import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/friend_repository.dart';
import 'package:squadquest/screens/friends/friends_screen.dart';

/// In-memory fake: serves friends + requests, records sends/responses.
class FakeFriendRepository implements FriendRepository {
  FakeFriendRepository({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
  });

  List<Friend> friends;
  List<FriendRequest> incoming;
  List<FriendRequest> outgoing;

  String? sentPhone;
  String? respondedId;
  bool? respondedAccept;

  @override
  Future<List<Friend>> list() async => friends;

  @override
  Future<FriendRequests> requests() async =>
      FriendRequests(incoming: incoming, outgoing: outgoing);

  @override
  Future<String> sendRequest(String phone) async {
    sentPhone = phone;
    return 'requested';
  }

  @override
  Future<void> respond(String requestId, {required bool accept}) async {
    respondedId = requestId;
    respondedAccept = accept;
  }
}

Widget _app(FakeFriendRepository fake) => ProviderScope(
  overrides: [friendRepositoryProvider.overrideWithValue(fake)],
  child: const MaterialApp(home: FriendsScreen()),
);

void main() {
  testWidgets('renders accepted friends, incoming + outgoing requests', (
    tester,
  ) async {
    final fake = FakeFriendRepository(
      friends: const [Friend(id: 'f1', firstName: 'Katie', onV2: true)],
      incoming: const [
        FriendRequest(
          id: 'r1',
          profile: Friend(id: 'p1', firstName: 'Sam'),
        ),
      ],
      outgoing: const [
        FriendRequest(
          id: 'r2',
          profile: Friend(id: 'p2', firstName: 'Jordan'),
        ),
      ],
    );
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    expect(find.text('Katie'), findsOneWidget);
    expect(find.byKey(const Key('incoming_r1')), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.byKey(const Key('outgoing_r2')), findsOneWidget);
    expect(find.text('Jordan'), findsOneWidget);
  });

  testWidgets('accepting an incoming request calls respond(accept:true)', (
    tester,
  ) async {
    final fake = FakeFriendRepository(
      incoming: const [
        FriendRequest(
          id: 'r1',
          profile: Friend(id: 'p1', firstName: 'Sam'),
        ),
      ],
    );
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accept_r1')));
    // Don't pumpAndSettle: the tile shows a transient spinner while responding.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.respondedId, 'r1');
    expect(fake.respondedAccept, true);
  });

  testWidgets('add-by-phone sends a request with the entered number', (
    tester,
  ) async {
    final fake = FakeFriendRepository();
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('addFriendPhoneField')),
      '+12155551000',
    );
    await tester.tap(find.byKey(const Key('addFriendSend')));
    await tester.pumpAndSettle();

    expect(fake.sentPhone, '+12155551000');
  });

  testWidgets('empty state when there are no friends', (tester) async {
    final fake = FakeFriendRepository();
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('friendsEmpty')), findsOneWidget);
  });
}
