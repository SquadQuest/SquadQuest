import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/controllers/instances.dart';
import 'package:squad_quest/models/instance.dart';

class EventDetailsScreen extends ConsumerStatefulWidget {
  final InstanceID id;

  const EventDetailsScreen({super.key, required this.id});

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  Instance? instance;
  final List<bool> _rsvpSelection = [false, false, false, false];

  @override
  void initState() {
    super.initState();

    ref
        .read(instancesProvider.notifier)
        .getById(widget.id)
        .then((Instance instance) {
      setState(() {
        this.instance = instance;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final instancesController = ref.read(instancesProvider.notifier);

    return SafeArea(
      child: Scaffold(
        appBar: instance == null
            ? null
            : AppBar(
                title: Text(instance!.title),
              ),
        body: instance == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Event Details Screen for ${instance!.title}'),
                      Text('Location: ${instance!.locationDescription}'),
                      Text('Topic: ${instance!.topic?.name}'),
                      Text('Posted by: ${instance!.createdBy?.fullName}'),
                      Text(
                          'Date: ${eventDateFormat.format(instance!.startTimeMin)}'),
                      Text(
                          'Starting between: ${eventTimeFormat.format(instance!.startTimeMin)}–${eventTimeFormat.format(instance!.startTimeMax)}'),
                      const Spacer(flex: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'RSVP: ',
                          ),
                          ToggleButtons(
                            isSelected: _rsvpSelection,
                            onPressed: (int index) async {
                              setState(() {
                                for (int buttonIndex = 0;
                                    buttonIndex < _rsvpSelection.length;
                                    buttonIndex++) {
                                  _rsvpSelection[buttonIndex] =
                                      buttonIndex == index &&
                                          !_rsvpSelection[index];
                                }
                              });

                              final updatedInstanceMember =
                                  await instancesController.rsvp(
                                      instance!,
                                      _rsvpSelection[index]
                                          ? InstanceMemberStatus
                                              .values[index + 1]
                                          : null);

                              // TODO: apply updatedInstanceMember to any already-loaded list
                              updatedInstanceMember;
                            },
                            children: const [
                              Text('No'),
                              Text('Maybe'),
                              Text('Yes'),
                              Text('OMW')
                            ],
                          ),
                        ],
                      )
                    ])),
      ),
    );
  }
}
