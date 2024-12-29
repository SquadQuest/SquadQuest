import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_screen/test_screen.dart';

import '../../mocks.dart';
import 'package:squadquest/screens/settings.dart';

void main() {
  testScreenUI(
    'Initial state',
    () async => buildMockEnvironment(
      const SettingsScreen(),
    ),
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
    },
  );

  testScreenUI(
    'Developer mode toggle',
    () async => buildMockEnvironment(
      const SettingsScreen(),
    ),
    goldenDir: 'developer-mode',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Scroll to developer section
      await tester.scrollUntilVisible(
        find.text('Developer'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      // Find and tap the developer mode switch
      final developerModeSwitch = find.ancestor(
        of: find.text('Developer Mode'),
        matching: find.byType(ListTile),
      );
      await tester.tap(find.descendant(
        of: developerModeSwitch,
        matching: find.byType(Switch),
      ));
      await tester.pumpAndSettle();

      // Verify developer settings become visible in order
      expect(find.text('Notification Permission'), findsOneWidget);
      expect(find.text('Clear App Data'), findsOneWidget);

      // Scroll to see remaining developer options
      await tester.scrollUntilVisible(
        find.text('FCM Token'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Installer Store'), findsOneWidget);
      expect(find.text('Browser Name'), findsOneWidget);
      expect(find.text('Browser Version'), findsOneWidget);
      expect(find.text('FCM Token'), findsOneWidget);
    },
  );

  testScreenUI(
    'Show notification details',
    () async => buildMockEnvironment(
      const SettingsScreen(),
    ),
    goldenDir: 'notification-details',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Scroll to notifications section
      await tester.scrollUntilVisible(
        find.text('Notifications'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      // Find and tap the show details switch
      final showDetailsSwitch = find.ancestor(
        of: find.text('Show Details'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(
        of: showDetailsSwitch,
        matching: find.byType(Switch),
      ));
      await tester.pumpAndSettle();

      // Verify notification categories in order
      expect(find.text('Friend Requests'), findsOneWidget);
      expect(find.text('Event Invitations'), findsOneWidget);
      expect(find.text('Event Changes'), findsOneWidget);
      expect(find.text('New Friends Event'), findsOneWidget);
      expect(find.text('New Public Event'), findsOneWidget);
      expect(find.text('Guest RSVPs'), findsOneWidget);
      expect(find.text('Friends OMW'), findsOneWidget);
      expect(find.text('Event Chat'), findsOneWidget);
    },
  );
}
