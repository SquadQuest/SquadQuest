import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_screen/test_screen.dart';

import '../../mocks.dart';
import 'package:squadquest/ui/friends/friends_screen.dart';

void main() {
  testScreenUI(
    'Initial State - Friends list',
    () async => buildMockEnvironment(
      const FriendsScreen(),
    ),
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      expect(find.text('Friends'), findsExactly(2));
    },
  );

  testScreenUI(
    'Add friend dialog',
    () async => buildMockEnvironment(
      const FriendsScreen(),
    ),
    goldenDir: 'add-friend',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Find the add friend button by its text
      final addFriendButton = find.text('Add Friend');
      expect(addFriendButton, findsOneWidget);

      // Open add friend dialog
      await tester.tap(addFriendButton);
      await tester.pumpAndSettle();

      // Verify dialog options
      expect(find.text('By Phone Number'), findsOneWidget);
      expect(find.text('From Contacts'), findsOneWidget);
    },
  );

  testScreenUI(
    'Friends list with requests',
    () async => buildMockEnvironment(
      const FriendsScreen(),
      scenario: 'friend-requests',
    ),
    goldenDir: 'friend-requests',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Verify friend requests section exists
      expect(find.text('Friend Requests'), findsOneWidget);

      // Accept friend request
      final acceptButton = find.widgetWithText(FilledButton, 'Accept');
      await tester.tap(acceptButton);
      await tester.pumpAndSettle();

      // Verify success message in snackbar
      expect(find.text('Friend request accepted!'), findsOneWidget);
    },
  );

  testScreenUI(
    'Empty state',
    () async => buildMockEnvironment(
      const FriendsScreen(),
      scenario: 'no-friends',
    ),
    goldenDir: 'no-friends',
    // onlyPlatform: UITargetPlatform.webAndroid,
    onTest: (WidgetTester tester) async {
      // Verify empty state shows add friend button
      expect(find.text('Add Your First Friend'), findsOneWidget);
    },
  );
}
