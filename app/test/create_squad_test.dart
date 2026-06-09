import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/friend_repository.dart';
import 'package:squadquest/screens/squads/create_squad_screen.dart';

class FakeFriendRepository implements FriendRepository {
  FakeFriendRepository(this._friends);
  final List<Friend> _friends;
  @override
  Future<List<Friend>> list() async => _friends;
}

void main() {
  testWidgets('create-squad lists friends to pick from', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendRepositoryProvider.overrideWithValue(
            FakeFriendRepository(const [
              Friend(id: 'f1', firstName: 'Katie'),
              Friend(id: 'f2', firstName: 'Mike'),
            ]),
          ),
        ],
        child: const MaterialApp(home: CreateSquadScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('squadNameField')), findsOneWidget);
    expect(find.byKey(const Key('friendPicker')), findsOneWidget);
    expect(find.byKey(const Key('friend_f1')), findsOneWidget);
    expect(find.text('Katie'), findsOneWidget);
    expect(find.text('Mike'), findsOneWidget);
    expect(find.byKey(const Key('createSquadButton')), findsOneWidget);
  });

  testWidgets('shows a solo hint when there are no friends', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendRepositoryProvider.overrideWithValue(
            FakeFriendRepository(const []),
          ),
        ],
        child: const MaterialApp(home: CreateSquadScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('create the squad solo'), findsOneWidget);
  });
}
