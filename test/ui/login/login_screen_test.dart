import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/ui/login/widgets/verify_form.dart';
import 'package:test_screen/test_screen.dart';
import 'package:pinput/pinput.dart';

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

      // Submit form
      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Send login code via SMS'));
      await tester.pump(); // Process the tap

      // Verify loading state appears
      expect(find.text('Sending login code...', findRichText: true), findsOne);
      await tester.pump(Duration(milliseconds: 150));
    },
  );

  testScreenUI(
    'Navigation to verify screen',
    () async => buildMockEnvironment(
      const LoginScreen(),
    ),
    goldenDir: 'verify-navigation',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Navigate to verify screen
      await tester.enterText(find.byType(TextFormField), '12345678901');
      await tester.pumpAndSettle();
      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Send login code via SMS'));
      await tester.pump(); // Process the tap
      await tester.pump(); // Process state change
      await tester.pump(Duration(milliseconds: 100)); // Process navigation

      // Verify we're on the verify screen
      expect(find.text('Verify phone number'), findsOneWidget);
      expect(find.text('Enter the code sent to the number:'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(VerifyForm),
              matching: find.text('(234) 567-8901')),
          findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Verify'), findsOneWidget);
    },
  );

  testScreenUI(
    'Verify code validation',
    () async => buildMockEnvironment(
      const LoginScreen(),
    ),
    goldenDir: 'verify-validation',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Navigate to verify screen
      await tester.enterText(find.byType(TextFormField), '12345678901');
      await tester.pumpAndSettle();
      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Send login code via SMS'));
      await tester.pump(); // Process the tap
      await tester.pump(); // Process state change
      await tester.pump(Duration(milliseconds: 100)); // Process navigation

      // Verify we're on the verify screen
      expect(find.text('Verify phone number'), findsOneWidget);

      // Enter invalid code
      await tester.enterText(find.byType(Pinput), '123'); // Too short
      await simulateKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Try to submit
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pump(); // Process the tap
      await tester.pump(); // Process state change

      // Verify error snackbar appears
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Token has expired or is invalid'),
        ),
        findsOneWidget,
      );
    },
  );

  testScreenUI(
    'Submit verification code',
    () async => buildMockEnvironment(
      const LoginScreen(),
    ),
    goldenDir: 'verify-submit',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Navigate to verify screen
      await tester.enterText(find.byType(TextFormField), '12345678901');
      await tester.pumpAndSettle();
      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Send login code via SMS'));
      await tester.pump(); // Process the tap
      await tester.pump(); // Process state change
      await tester.pump(Duration(milliseconds: 100)); // Process navigation

      // Verify we're on the verify screen
      expect(find.text('Verify phone number'), findsOneWidget);

      // Enter invalid code
      await tester.enterText(find.byType(Pinput), '123456');
      await tester.pump();
      await tester.pump(Duration(milliseconds: 500));

      // Verify loadmask
      expect(find.text('Verifying code...'), findsOneWidget);
    },
  );
}
