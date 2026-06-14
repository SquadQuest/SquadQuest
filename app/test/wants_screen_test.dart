import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/activity.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/want.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/friend_repository.dart';
import 'package:squadquest/repositories/want_repository.dart';
import 'package:squadquest/screens/wants/wants_screen.dart';

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

class _FakeWantRepository implements WantRepository {
  _FakeWantRepository({this.own = const [], this.invited = const []});
  List<Want> own;
  List<Want> invited;
  String? respondedId;
  String? respondedValue;
  String? ignoredId;
  final invitedProfileIds = <String>[];
  final uninvitedProfileIds = <String>[];

  @override
  Future<List<Want>> listOwn({bool includeArchived = false}) async => own;
  @override
  Future<List<Want>> listInvited() async => invited;

  @override
  Future<Want> respond(String id, String value) async {
    respondedId = id;
    respondedValue = value;
    return invited.firstWhere((w) => w.id == id);
  }

  @override
  Future<void> ignore(String id) async {
    ignoredId = id;
  }

  // Unused in these tests:
  @override
  Future<Want> create({
    String? activityTypeId,
    String? activityTypeLabel,
    String? title,
    String? location,
    String? notes,
    String kind = 'one_shot',
    List<String> inviteeIds = const [],
  }) async => throw UnimplementedError();
  @override
  Future<Want> update(
    String id, {
    String? activityTypeId,
    String? title,
    String? location,
    String? notes,
    String? kind,
  }) async => throw UnimplementedError();
  @override
  Future<void> delete(String id) async {}
  @override
  Future<Want> invite(String id, List<String> profileIds) async {
    invitedProfileIds.addAll(profileIds);
    return own.firstWhere((w) => w.id == id);
  }

  @override
  Future<Want> uninvite(String id, String profileId) async {
    uninvitedProfileIds.add(profileId);
    return own.firstWhere((w) => w.id == id);
  }

  @override
  Future<Want> clearResponse(String id) async => throw UnimplementedError();
  @override
  Future<void> unignore(String id) async {}
  @override
  Future<Activity> promote(
    String id, {
    List<String>? audiencePersonIds,
    List<String> timeOptions = const [],
    List<String> locationOptions = const [],
    bool allowSuggestions = false,
    String? squadId,
  }) async => throw UnimplementedError();
}

Want _want(String id, {String? title, List<WantInvitee> invitees = const []}) =>
    Want(
      id: id,
      activityTypeLabel: 'Go Paddleboarding',
      title: title,
      invitees: invitees,
    );

Future<_FakeWantRepository> _pump(
  WidgetTester tester, {
  List<Want> own = const [],
  List<Want> invited = const [],
  List<Friend> friends = const [],
}) async {
  final repo = _FakeWantRepository(own: own, invited: invited);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wantRepositoryProvider.overrideWithValue(repo),
        friendRepositoryProvider.overrideWithValue(
          _FakeFriendRepository(friends),
        ),
      ],
      child: const MaterialApp(home: WantsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('renders own + invited wants', (tester) async {
    await _pump(
      tester,
      own: [_want('w1', title: 'FDR lake')],
      invited: [_want('w2', title: 'Climb')],
    );
    expect(find.byKey(const Key('want_w1')), findsOneWidget);
    expect(find.byKey(const Key('invitedWant_w2')), findsOneWidget);
    expect(find.text('FDR lake'), findsOneWidget);
  });

  testWidgets('responding to an invite calls the repo', (tester) async {
    final repo = await _pump(tester, invited: [_want('w2', title: 'Climb')]);
    await tester.tap(find.byKey(const Key('respond_in_w2')));
    await tester.pump();
    expect(repo.respondedId, 'w2');
    expect(repo.respondedValue, 'in');
  });

  testWidgets('ignoring an invite calls the repo', (tester) async {
    final repo = await _pump(tester, invited: [_want('w3')]);
    await tester.tap(find.byKey(const Key('ignoreWant_w3')));
    await tester.pump();
    expect(repo.ignoredId, 'w3');
  });

  testWidgets('empty state shows the capture prompt', (tester) async {
    await _pump(tester);
    expect(
      find.textContaining('Capture it here and make it happen'),
      findsOneWidget,
    );
  });

  testWidgets('manage invites adds a new friend and removes an invitee', (
    tester,
  ) async {
    final repo = await _pump(
      tester,
      own: [
        _want(
          'w1',
          title: 'FDR lake',
          invitees: const [WantInvitee(profileId: 'f1', name: 'Katie')],
        ),
      ],
      friends: const [
        Friend(id: 'f1', firstName: 'Katie'), // already invited
        Friend(id: 'f2', firstName: 'Mike'), // not yet
      ],
    );

    // Open the want menu → Manage invites.
    await tester.tap(find.byKey(const Key('wantMenu_w1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage invites'));
    await tester.pumpAndSettle();

    // Current invitee is checked; the other friend isn't.
    expect(find.byKey(const Key('manageInvitesList')), findsOneWidget);

    // Invite Mike (toggle on) → invite() called with f2.
    await tester.tap(find.byKey(const Key('inviteToggle_f2')));
    await tester.pumpAndSettle();
    expect(repo.invitedProfileIds, contains('f2'));

    // Remove Katie (toggle off) → uninvite() called with f1.
    await tester.tap(find.byKey(const Key('inviteToggle_f1')));
    await tester.pumpAndSettle();
    expect(repo.uninvitedProfileIds, contains('f1'));
  });
}
