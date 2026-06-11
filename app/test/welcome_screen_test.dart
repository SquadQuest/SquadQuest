import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/models/profile.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/profile_repository.dart';
import 'package:squadquest/screens/welcome/welcome_screen.dart';

/// Records the name passed to updateProfile and echoes back a named profile.
class FakeProfileRepository implements ProfileRepository {
  String? lastFirstName;
  String? lastLastName;

  @override
  Future<Profile> me() async => const Profile(id: 'me');

  @override
  Future<Profile> updateProfile({
    String? firstName,
    String? lastName,
    String? photo,
  }) async {
    lastFirstName = firstName;
    lastLastName = lastName;
    return Profile(id: 'me', firstName: firstName, lastName: lastName);
  }
}

void main() {
  testWidgets('entering a name calls updateProfile with the trimmed values', (
    tester,
  ) async {
    final fake = FakeProfileRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );

    expect(find.byKey(const Key('welcomeForm')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('firstNameField')), 'Chris');
    await tester.enterText(find.byKey(const Key('lastNameField')), 'Alfano');
    await tester.tap(find.byKey(const Key('welcomeContinue')));
    // Don't pumpAndSettle: on success the button shows an indefinite spinner
    // (the real app's router redirects away; there's no router here).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.lastFirstName, 'Chris');
    expect(fake.lastLastName, 'Alfano');
  });

  testWidgets('a blank first name is rejected without calling the repo', (
    tester,
  ) async {
    final fake = FakeProfileRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('welcomeContinue')));
    await tester.pumpAndSettle();

    expect(fake.lastFirstName, isNull);
    expect(find.text('Please enter your first name.'), findsOneWidget);
  });
}
