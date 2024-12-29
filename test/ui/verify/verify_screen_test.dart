import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_screen/test_screen.dart';

import '../../mocks.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/screens/verify.dart';

void main() {
  testScreenUI(
    'Initial State',
    () async => buildMockEnvironment(
      const VerifyScreen(),
    ),
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Verify header text
      expect(find.text('Verify phone number'), findsOneWidget);

      // Verify code field
      expect(
        find.byType(TextFormField),
        findsOneWidget,
      );
      expect(
        find.text('Enter the code sent to (555) 555-5555'),
        findsOneWidget,
      );

      // Verify verify button
      expect(
        find.widgetWithText(ElevatedButton, 'Verify'),
        findsOneWidget,
      );
    },
  );

  testScreenUI(
    'Code validation',
    () async => buildMockEnvironment(
      const VerifyScreen(),
    ),
    goldenDir: 'code-validation',
    // onlyPlatform: UITargetPlatform.webIos,
    onTest: (WidgetTester tester) async {
      // Enter invalid code and wait for validation
      await tester.enterText(find.byType(TextFormField), '123'); // Too short
      await tester.pumpAndSettle();

      // Try to submit
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verify validation error
      expect(
        find.text('Please enter a valid one-time password'),
        findsOneWidget,
      );
    },
  );

  testScreenUI(
    'Submit code',
    () async => buildMockEnvironment(
      const VerifyScreen(),
    ),
    goldenDir: 'submit-code',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Enter valid code
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.pumpAndSettle();

      // Verify no validation error
      expect(
        find.text('Please enter a valid one-time password'),
        findsNothing,
      );

      // Submit form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pump();

      // Verify loading state appears
      expect(find.text('Verifying code...', findRichText: true), findsOne);
      await tester.pumpAndSettle();
    },
  );
}
