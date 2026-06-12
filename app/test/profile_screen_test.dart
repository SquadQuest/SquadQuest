import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/profile.dart';
import 'package:squadquest/providers/auth_controller.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/profile_repository.dart';
import 'package:squadquest/repositories/token_store.dart';
import 'package:squadquest/screens/profile/profile_screen.dart';

/// A token store that always reports a session (load is a no-op), so the auth
/// controller resolves to SignedIn without touching the platform keychain.
class _FakeTokenStore extends TokenStore {
  _FakeTokenStore() {
    accessToken = 'test-access';
    refreshToken = 'test-refresh';
  }
  @override
  Future<void> load() async {}
}

/// Returns [profile] from me(); records the last updateProfile args.
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.profile);
  final Profile profile;
  String? lastFirstName;
  String? lastLastName;
  String? lastPhoto;
  bool updateCalled = false;

  @override
  Future<Profile> me() async => profile;

  @override
  Future<Profile> updateProfile({
    String? firstName,
    String? lastName,
    String? photo,
  }) async {
    updateCalled = true;
    lastFirstName = firstName;
    lastLastName = lastName;
    lastPhoto = photo;
    return Profile(
      id: profile.id,
      firstName: firstName ?? profile.firstName,
      lastName: lastName ?? profile.lastName,
      photo: photo ?? profile.photo,
      phone: profile.phone,
    );
  }
}

/// Mounts ProfileScreen only once auth resolves to SignedIn — mirrors how the
/// real router gates /profile, so currentProfile is populated in initState.
class _Gate extends ConsumerWidget {
  const _Gate();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return auth is SignedIn ? const ProfileScreen() : const SizedBox.shrink();
  }
}

Future<_FakeProfileRepository> _pumpProfile(
  WidgetTester tester,
  Profile p,
) async {
  final repo = _FakeProfileRepository(p);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(_FakeTokenStore()),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: _Gate()),
    ),
  );
  await tester.pumpAndSettle(); // let _restore() resolve to SignedIn
  return repo;
}

void main() {
  const me = Profile(
    id: 'me',
    firstName: 'Chris',
    lastName: 'Alfano',
    phone: '+12155551234',
  );

  testWidgets('shows current name + read-only phone', (tester) async {
    await _pumpProfile(tester, me);

    expect(find.byKey(const Key('profileForm')), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Chris'), findsOneWidget);
    expect(find.text('+12155551234'), findsOneWidget);
    // Save is disabled until something changes.
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('saveProfileButton')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('editing the name enables Save and patches the profile', (
    tester,
  ) async {
    final repo = await _pumpProfile(tester, me);

    await tester.enterText(
      find.byKey(const Key('firstNameField')),
      'Christopher',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('saveProfileButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.updateCalled, isTrue);
    expect(repo.lastFirstName, 'Christopher');
  });

  testWidgets('clearing the first name disables Save (guard)', (tester) async {
    final repo = await _pumpProfile(tester, me);

    await tester.enterText(find.byKey(const Key('firstNameField')), '');
    await tester.pump();

    final save = tester.widget<FilledButton>(
      find.byKey(const Key('saveProfileButton')),
    );
    expect(save.onPressed, isNull);
    expect(repo.updateCalled, isFalse);
  });
}
