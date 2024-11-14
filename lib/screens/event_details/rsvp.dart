import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/controllers/location.dart';
import 'package:squadquest/controllers/rsvps.dart';

class EventDetailsRSVP extends ConsumerWidget {
  final Instance event;
  final InstanceMemberStatus? currentStatus;
  final bool isLoggedIn;

  const EventDetailsRSVP({
    super.key,
    required this.event,
    required this.currentStatus,
    required this.isLoggedIn,
  });

  Future<void> _saveRsvp(
      BuildContext context, WidgetRef ref, InstanceMemberStatus? status) async {
    try {
      final rsvpsController = ref.read(rsvpsProvider.notifier);
      final savedRsvp = await rsvpsController.save(event, status);

      // start or stop tracking
      final locationController = ref.read(locationControllerProvider);
      if (status == InstanceMemberStatus.omw) {
        await locationController.startTracking(event.id!);
      } else {
        await locationController.stopTracking(event.id!);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            savedRsvp == null
                ? 'You\'ve removed your RSVP'
                : 'You\'ve RSVPed ${savedRsvp.status.name}',
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save RSVP: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<bool> rsvpSelection = List.filled(4, false);

    if (currentStatus != null) {
      for (int buttonIndex = 0;
          buttonIndex < rsvpSelection.length;
          buttonIndex++) {
        rsvpSelection[buttonIndex] = buttonIndex == currentStatus!.index - 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Text(
            'RSVP: ',
          ),
          const SizedBox(width: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ToggleButtons(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  constraints: BoxConstraints.expand(
                      width: constraints.maxWidth / 4 -
                          (rsvpSelection.length - 1)),
                  isSelected: rsvpSelection,
                  onPressed: !isLoggedIn
                      ? null
                      : (int selectedIndex) async {
                          // convert index and button state to desired status
                          InstanceMemberStatus? status =
                              !rsvpSelection[selectedIndex]
                                  ? InstanceMemberStatus
                                      .values[selectedIndex + 1]
                                  : null;

                          // save
                          await _saveRsvp(context, ref, status);
                        },
                  children: const [
                    Text('No'),
                    Text('Maybe'),
                    Text('Yes'),
                    Text('OMW'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
