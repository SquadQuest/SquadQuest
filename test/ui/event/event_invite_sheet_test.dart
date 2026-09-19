import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks.dart';

import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/ui/event/widgets/event_invite_sheet.dart';

/// Opens the invite sheet inside a real route so that the pop it performs on
/// success behaves the way it does in the app.
Future<MockRsvpsController> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(buildMockEnvironment(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => EventInviteSheet(eventId: mockEvent.id!),
            ),
            child: const Text('open sheet'),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.text('open sheet'));
  await tester.pumpAndSettle();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(EventInviteSheet)),
  );

  return container.read(rsvpsProvider.notifier) as MockRsvpsController;
}

void main() {
  testWidgets('shows progress and blocks a second tap while inviting',
      (WidgetTester tester) async {
    final rsvps = await _openSheet(tester);
    final gate = Completer<void>();
    rsvps.inviteGate = gate;

    // nothing selected yet, so the button starts disabled
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite'));
    await tester.pump();

    // the request is in flight: label swaps for a spinner and the button locks
    expect(find.text('Invite'), findsNothing);
    expect(find.text('Inviting…'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(rsvps.inviteCallCount, 1);

    // an impatient second tap must not send a duplicate request -- that was
    // what made the invite fail while the invitations had actually gone out
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();
    expect(rsvps.inviteCallCount, 1);

    gate.complete();
    await tester.pumpAndSettle();

    // sheet closes and reports what it sent
    expect(rsvps.inviteCallCount, 1);
    expect(find.byType(EventInviteSheet), findsNothing);
    expect(find.text('Invited 1 friend'), findsOneWidget);
  });
}
