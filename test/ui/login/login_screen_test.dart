import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_screen/test_screen.dart';

import '../../mocks.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/ui/login/login_screen.dart';

void main() {
  testScreenUI(
    'Initial State',
    () async => buildMockEnvironment(
      const LoginScreen(),
    ),
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Verify header text
      expect(find.text('Log in to SquadQuest'), findsOneWidget);

      // Verify phone number field
      expect(
        find.byType(TextFormField),
        findsOneWidget,
      );
      expect(find.text('Phone number'), findsOneWidget);

      // Verify login button
      expect(
        find.widgetWithText(ElevatedButton, 'Send login code via SMS'),
        findsOneWidget,
      );

      // Verify privacy text
      expect(
        find.text('SquadQuest is focused on privacy.\n\n'
            'Only people who know your phone number already can send you a friend request,'
            ' and only people you\'ve accepted friend requests from can see any of your personal details.'),
        findsOneWidget,
      );
    },
  );

  testScreenUI(
    'Phone number validation',
    () async => buildMockEnvironment(
      const LoginScreen(),
    ),
    goldenDir: 'phone-validation',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Enter invalid phone number and wait for validation
      await tester.enterText(find.byType(TextFormField), '123'); // Too short
      await tester.pumpAndSettle(); // Wait for validation to complete

      // Verify validation error
      expect(find.text('Invalid US number'), findsOneWidget);

      // Wait for any remaining animations
      await tester.pumpAndSettle();
    },
  );

  testScreenUI(
    'Submit phone number',
    () async => buildMockEnvironment(
      const LoginScreen(),
    ),
    goldenDir: 'submit-phone',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Enter valid phone number and wait for validation
      await tester.enterText(find.byType(TextFormField), '12345678900');
      await tester.pumpAndSettle(); // Wait for validation to complete

      // Verify no validation error
      expect(find.text('Invalid US number'), findsNothing);

      // Submit form and wait for validation
      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Send login code via SMS'));
      await tester.pump(
          const Duration(milliseconds: 50)); // Wait for validation to complete

      // Verify loading state appears
      expect(find.byType(AppScaffold), findsOneWidget);
      final loadingScaffold =
          tester.widget<AppScaffold>(find.byType(AppScaffold));
      expect(loadingScaffold.loadMask, equals('Sending login code...'));

      // Wait for any remaining animations
      await tester.pumpAndSettle();
    },
  );
}
