import 'package:flutter_test/flutter_test.dart';
import 'package:test_screen/test_screen.dart';

import '../../mocks.dart';

import 'package:squadquest/ui/event/event_screen.dart';
import 'package:squadquest/ui/event/widgets/event_chat_sheet.dart';

void main() {
  group('EventScreen', () {
    testScreenUI(
        'Initial state', () async => EventScreen(eventId: mockEvent.id!),
        onTest: (WidgetTester tester) async {
      // Verify event details are displayed
      expect(find.text(mockEvent.notes!.split('\n')[0]), findsOneWidget);
      expect(find.text(mockEvent.createdBy!.displayName), findsOneWidget);
      expect(find.text(mockEvent.locationDescription), findsOneWidget);

      // Verify pinned message is not displayed by default
      expect(find.text('Latest Update from Host'), findsNothing);
      expect(find.text('UPDATE: Building code is 1234#'), findsNothing);
    });

    testScreenUI(
        'With pinned message', () async => EventScreen(eventId: mockEvent.id!),
        config:
            buildTestScreenConfig(container: mocksContainerWithPinnedMessage),
        goldenDir: 'with_pinned', onTest: (WidgetTester tester) async {
      // Verify latest pinned message is displayed
      expect(find.text('Latest Update from Host'), findsOneWidget);
      expect(find.text('UPDATE: Building code is 1234#'), findsOneWidget);
      expect(find.text('30m ago'), findsOneWidget);

      // Verify bulletin is tappable
      await tester.tap(find.text('Latest Update from Host'));
      await tester.pumpAndSettle();

      // Verify chat sheet is shown
      expect(find.byType(EventChatSheet), findsOneWidget);
    });
  });
}
