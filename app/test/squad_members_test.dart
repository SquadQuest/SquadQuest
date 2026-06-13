import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/profile.dart';
import 'package:squadquest/models/squad.dart';
import 'package:squadquest/providers/auth_controller.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/friend_repository.dart';
import 'package:squadquest/repositories/profile_repository.dart';
import 'package:squadquest/repositories/squad_repository.dart';
import 'package:squadquest/repositories/token_store.dart';
import 'package:squadquest/screens/squads/squad_detail_screen.dart';

/// Signed-in without touching the keychain (mirrors profile_screen_test).
class _FakeTokenStore extends TokenStore {
  _FakeTokenStore() {
    accessToken = 'test-access';
    refreshToken = 'test-refresh';
  }
  @override
  Future<void> load() async {}
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.profile);
  final Profile profile;
  @override
  Future<Profile> me() async => profile;
  @override
  Future<Profile> updateProfile({
    String? firstName,
    String? lastName,
    String? photo,
  }) async => profile;
}

class _FakeFriendRepository implements FriendRepository {
  _FakeFriendRepository(this._friends);
  final List<Friend> _friends;
  @override
  Future<List<Friend>> list() async => _friends;
  @override
  Future<FriendRequests> requests() async => const FriendRequests();
  @override
  Future<String> sendRequest(String phone) async => 'requested';
  @override
  Future<void> accept(String requestId) async {}
  @override
  Future<void> ignore(String requestId) async {}
  @override
  Future<void> unignore(String requestId) async {}
  @override
  Future<List<IgnoredItem>> ignored() async => const [];
}

/// Records addMember calls; returns a fixed roster.
class _FakeSquadRepository implements SquadRepository {
  _FakeSquadRepository(this._detail);
  final SquadDetail _detail;
  final addedProfileIds = <String>[];

  @override
  Future<List<Squad>> list() async => const [];
  @override
  Future<SquadDetail> create(String name, List<String> memberIds) async =>
      _detail;
  @override
  Future<SquadDetail> get(String squadId) async => _detail;
  @override
  Future<SquadDetail> addMember(String squadId, String profileId) async {
    addedProfileIds.add(profileId);
    return _detail;
  }
}

/// Mounts the screen only once auth resolves to SignedIn (the captain check
/// reads currentProfile), mirroring how the router gates the route.
class _Gate extends ConsumerWidget {
  const _Gate({required this.squadId});
  final String squadId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return auth is SignedIn
        ? SquadDetailScreen(squadId: squadId)
        : const SizedBox.shrink();
  }
}

void main() {
  const me = Profile(id: 'me', firstName: 'Cap', phone: '+1');

  Future<_FakeSquadRepository> pump(
    WidgetTester tester, {
    required SquadDetail detail,
    required List<Friend> friends,
  }) async {
    final squadRepo = _FakeSquadRepository(detail);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(_FakeTokenStore()),
          profileRepositoryProvider.overrideWithValue(
            _FakeProfileRepository(me),
          ),
          squadRepositoryProvider.overrideWithValue(squadRepo),
          friendRepositoryProvider.overrideWithValue(
            _FakeFriendRepository(friends),
          ),
        ],
        child: const MaterialApp(home: _Gate(squadId: 's1')),
      ),
    );
    await tester.pumpAndSettle();
    return squadRepo;
  }

  testWidgets('captain sees roster + can add a non-member friend', (
    tester,
  ) async {
    final detail = SquadDetail(
      id: 's1',
      name: 'Wednesday Riders',
      members: const [
        SquadMember(id: 'me', firstName: 'Cap', role: 'captain'),
        SquadMember(id: 'f1', firstName: 'Katie', role: 'member'),
      ],
    );
    final repo = await pump(
      tester,
      detail: detail,
      friends: const [
        Friend(id: 'f1', firstName: 'Katie'), // already a member → excluded
        Friend(id: 'f2', firstName: 'Mike'), // addable
      ],
    );

    // Roster renders with the captain badge.
    expect(find.byKey(const Key('squadMember_me')), findsOneWidget);
    expect(find.text('Captain'), findsOneWidget);
    expect(find.byKey(const Key('addMembersButton')), findsOneWidget);

    // Open the picker → only the non-member friend is offered.
    await tester.tap(find.byKey(const Key('addMembersButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addFriend_f2')), findsOneWidget);
    expect(find.byKey(const Key('addFriend_f1')), findsNothing);

    // Tapping adds that friend via the repo.
    await tester.tap(find.byKey(const Key('addFriend_f2')));
    await tester.pumpAndSettle();
    expect(repo.addedProfileIds, ['f2']);
  });

  testWidgets('non-captain member sees the roster read-only', (tester) async {
    final detail = SquadDetail(
      id: 's1',
      name: 'Wednesday Riders',
      members: const [
        SquadMember(id: 'other', firstName: 'Boss', role: 'captain'),
        SquadMember(id: 'me', firstName: 'Cap', role: 'member'),
      ],
    );
    await pump(tester, detail: detail, friends: const []);
    expect(find.byKey(const Key('squadMembersList')), findsOneWidget);
    expect(find.byKey(const Key('addMembersButton')), findsNothing);
  });
}
