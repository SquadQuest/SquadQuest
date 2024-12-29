import 'package:flutter_test/flutter_test.dart';
import 'package:test_screen/test_screen.dart';

import '../../mocks.dart';
import 'package:squadquest/screens/profile_form.dart';

void main() {
  group('ProfileFormScreen', () {
    testScreenUI(
      'Initial state - Edit profile',
      () async => buildMockEnvironment(
        const ProfileFormScreen(),
        scenario: 'edit-profile',
      ),
      onTest: (WidgetTester tester) async {
        // Verify edit mode doesn't show welcome message
        expect(find.text('Welcome to SquadQuest!'), findsNothing);

        // Verify form fields are present and populated
        expect(find.text('First Name'), findsOneWidget);
        expect(find.text('Last Name'), findsOneWidget);
        expect(find.text('Trail Color'), findsOneWidget);

        // Verify submit button
        expect(find.text('Save Changes'), findsOneWidget);
      },
    );
  });

  testScreenUI(
    'Initial state - New profile',
    () async => buildMockEnvironment(
      const ProfileFormScreen(),
      scenario: 'new-profile',
    ),
    goldenDir: 'new-profile',
    onTest: (WidgetTester tester) async {
      // Verify welcome message is shown
      expect(find.text('Welcome to SquadQuest!'), findsOneWidget);
      expect(
        find.text('Tell us a bit about yourself to get started'),
        findsOneWidget,
      );

      // Verify form fields are present
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.text('Trail Color'), findsOneWidget);

      // Verify submit button
      expect(find.text('Get Started'), findsOneWidget);
    },
  );
}
