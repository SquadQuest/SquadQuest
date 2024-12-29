import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_screen/test_screen.dart';

import '../../mocks.dart';
import 'package:squadquest/screens/topics.dart';

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

      // Verify sections
      expect(find.text('Subscribed'), findsWidgets);
      expect(find.text('Available'), findsOneWidget);

      // Find and tap a checkbox for sports.basketball
      await tester.tap(find.text('sports.basketball', findRichText: true));
      await tester.pumpAndSettle();

      // Verify checkbox state changed
      final checkboxWidget = tester.widget<CheckboxListTile>(find.ancestor(
          of: find.text('sports.basketball', findRichText: true),
          matching: find.byType(CheckboxListTile)));
      expect(checkboxWidget.value, isTrue);
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
              of: find.text('sports.basketball', findRichText: true),
              matching: find.byType(CheckboxListTile)),
          findsOneWidget);
      expect(
          find.ancestor(
              of: find.text('party.house', findRichText: true),
              matching: find.byType(CheckboxListTile)),
          findsNothing);
    },
  );
}
