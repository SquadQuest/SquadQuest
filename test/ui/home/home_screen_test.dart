import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/ui/core/widgets/event_card.dart';
import 'package:test_screen/test_screen.dart';

import '../../mocks.dart';
import 'package:squadquest/ui/home/home_screen.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/friend.dart';

void main() {
  testScreenUI(
    'Initial state - Feed view',
    () async => buildMockEnvironment(const HomeScreen()),
    onTest: (WidgetTester tester) async {
      // Verify app title
      expect(find.text('SquadQuest'), findsOneWidget);

      // Verify search button is present
      expect(find.byIcon(Icons.search), findsExactly(2));

      // Verify filter tabs are present
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Invited'), findsOneWidget);
      expect(find.text('Going'), findsOneWidget);
      expect(find.text('Hosting'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);

      // Verify Feed is selected by default
      expect(
        find.text('Events you\'re invited to or match your interests'),
        findsOneWidget,
      );

      // Verify create event FAB is present
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Create Event'), findsOneWidget);

      // Verify mock event is displayed
      expect(find.text(mockEvent.title), findsOneWidget);
      expect(find.text(mockEvent.locationDescription), findsOneWidget);
    },
  );

  testScreenUI(
    'Shows topics prompt when no subscriptions',
    () async => buildMockEnvironment(
      const HomeScreen(),
      scenario: 'no-subscriptions',
    ),
    goldenDir: 'no_subscriptions',
    onTest: (WidgetTester tester) async {
      // Verify topics prompt is shown
      expect(
        find.text('Subscribe to Topics'),
        findsOneWidget,
      );
      expect(
        find.text(
          'You haven\'t subscribed to any topics yet!\n\nTap here to head to the Topics screen and subscribe to some to see public events.',
        ),
        findsOneWidget,
      );
    },
  );

  testScreenUI(
    'Shows friend requests banner',
    () async => buildMockEnvironment(
      const HomeScreen(),
      scenario: 'friend-requests',
    ),
    goldenDir: 'friend_requests',
    onTest: (WidgetTester tester) async {
      // Verify friend requests banner is shown
      expect(find.text('New Friend Requests'), findsOneWidget);
      expect(
        find.text('${mockUser2.displayName} wants to be friends'),
        findsOneWidget,
      );
      expect(find.text('View'), findsOneWidget);
    },
  );

  testScreenUI(
    'Search functionality',
    () async => buildMockEnvironment(const HomeScreen()),
    goldenDir: 'search',
    onTest: (WidgetTester tester) async {
      // Initially search bar should be hidden
      expect(find.byType(TextField).hitTestable(), findsNothing);

      // Tap search icon
      await tester.tap(find.descendant(
          of: find.byType(AppBar), matching: find.byIcon(Icons.search)));
      await tester.pumpAndSettle();

      // Search bar should be visible
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search events...'), findsOneWidget);

      // FAB should be hidden while searching
      expect(find.byType(FloatingActionButton).hitTestable(), findsNothing);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'New Years');
      await tester.pumpAndSettle();

      // Verify mock event appears in search results
      expect(find.text(mockEvent.title), findsOneWidget);
    },
  );

  testScreenUI(
    'Filter switching',
    () async => buildMockEnvironment(const HomeScreen()),
    goldenDir: 'filter_switching',
    onTest: (WidgetTester tester) async {
      // Initially on Feed tab
      expect(find.text('Feed'), findsOneWidget);
      expect(
        find.text('Events you\'re invited to or match your interests'),
        findsOneWidget,
      );
      expect(find.byType(EventCard), findsExactly(1));

      // Switch to Invited tab
      await tester.tap(find.text('Invited'));
      await tester.pumpAndSettle();

      expect(
        find.text('Events awaiting your response'),
        findsOneWidget,
      );
      expect(find.byType(EventCard), findsNothing);

      // Switch to Going tab
      await tester.tap(find.text('Going'));
      await tester.pumpAndSettle();

      expect(
        find.text('Events you\'re attending'),
        findsOneWidget,
      );
      expect(find.byType(EventCard), findsNothing);

      // Scroll filter bar
      await tester.dragUntilVisible(
        find.text('Public'),
        find.ancestor(of: find.text('Feed'), matching: find.byType(ListView)),
        const Offset(-250, 0),
      );

      // Switch to Hosting tab
      await tester.tap(find.text('Hosting'));
      await tester.pumpAndSettle();

      expect(
        find.text('Events you\'re organizing'),
        findsOneWidget,
      );
      expect(find.byType(EventCard), findsExactly(1));

      // Switch to Public tab
      await tester.tap(find.text('Public'));
      await tester.pumpAndSettle();

      expect(
        find.text('All public events'),
        findsOneWidget,
      );
      expect(find.byType(EventCard), findsExactly(1));
    },
  );
}
