import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_screen/test_screen.dart';

import '../../mocks.dart';
import 'package:squadquest/ui/topics/topics_screen.dart';

void main() {
  testScreenUI(
    'Initial State',
    () async => buildMockEnvironment(
      const TopicsScreen(),
    ),
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Verify header text
      expect(
        find.text(
          'Select topics you are interested in to receive notifications when new events are posted',
        ),
        findsOneWidget,
      );

      // Verify search field
      expect(
          find.widgetWithText(TextFormField, 'Search topics'), findsOneWidget);
    },
  );

  testScreenUI(
    'Topic subscription',
    () async => buildMockEnvironment(
      const TopicsScreen(),
    ),
    goldenDir: 'topic-subscription',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Wait for list to populate
      await tester.pumpAndSettle();

      // Verify section header
      expect(find.text('Available Topics'), findsOneWidget);

      // Find and tap a switch for sports.basketball
      final sportsTile = find.ancestor(
        of: find.text('sports.basketball'),
        matching: find.byType(ListTile),
      );
      final sportsSwitch = find.descendant(
        of: sportsTile,
        matching: find.byType(Switch),
      );
      await tester.tap(sportsSwitch);
      await tester.pumpAndSettle();

      // Verify switch state changed
      final switchWidget = tester.widget<Switch>(sportsSwitch);
      expect(switchWidget.value, isTrue);
    },
  );

  testScreenUI(
    'Topic search',
    () async => buildMockEnvironment(
      const TopicsScreen(),
    ),
    goldenDir: 'topic-search',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Wait for list to populate
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextFormField), 'sports');
      await tester.pumpAndSettle();

      // Verify filtered results
      expect(
        find.ancestor(
          of: find.text('sports.basketball'),
          matching: find.byType(ListTile),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('party.house'),
          matching: find.byType(ListTile),
        ),
        findsNothing,
      );
    },
  );
}
