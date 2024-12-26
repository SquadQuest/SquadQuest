import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/ui/event/event_screen.dart';
import 'package:test_screen/test_screen.dart';

import '../../mocks.dart';

void main() {
  group('EventScreen', () {
    testScreenUI(
        'Initial state', () async => EventScreen(eventId: mockEvent.id!),
        onTest: (WidgetTester tester) async {
      // Verify event details are displayed
      expect(find.text(mockEvent.notes!.split('\n')[0]), findsOneWidget);
      expect(find.text(mockEvent.createdBy!.displayName), findsOneWidget);
      expect(find.text(mockEvent.locationDescription), findsOneWidget);
    });
  });
}
