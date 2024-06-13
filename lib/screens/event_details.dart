import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';

import 'package:squad_quest/controllers/auth.dart';
import 'package:squad_quest/controllers/instances.dart';
import 'package:squad_quest/controllers/rsvps.dart';
import 'package:squad_quest/models/instance.dart';

final _statusGroupOrder = {
  InstanceMemberStatus.omw: 0,
  InstanceMemberStatus.yes: 1,
  InstanceMemberStatus.maybe: 2,
  InstanceMemberStatus.no: 3,
  InstanceMemberStatus.invited: 4,
};

class EventDetailsScreen extends ConsumerStatefulWidget {
  final InstanceID id;

  const EventDetailsScreen({super.key, required this.id});

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  Instance? instance;
  final List<bool> _rsvpSelection = [false, false, false, false];
  List<InstanceMember>? rsvps;

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

      ref.read(rsvpsProvider.notifier).fetchByInstance(widget.id).then((rsvps) {
        setState(() {
          this.rsvps = rsvps;
        });

        ref.read(authControllerProvider.future).then((session) {
          if (session == null) {
            return;
          }

          final myRsvp = rsvps.cast<InstanceMember?>().firstWhere(
              (rsvp) => rsvp?.memberId == session.user.id,
              orElse: () => null);

          if (myRsvp != null && myRsvp.status.index > 0) {
            _rsvpSelection[myRsvp.status.index - 1] = true;
          }
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUser = ref.watch(userProvider);
    final rsvpsController = ref.read(rsvpsProvider.notifier);

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
                        Expanded(
                            child: rsvps == null
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : GroupedListView(
                                    elements: rsvps!,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    useStickyGroupSeparators: true,
                                    stickyHeaderBackgroundColor:
                                        Theme.of(context)
                                            .scaffoldBackgroundColor,
                                    groupBy: (InstanceMember rsvp) =>
                                        rsvp.status,
                                    groupComparator: (group1, group2) {
                                      return _statusGroupOrder[group1]!
                                          .compareTo(
                                              _statusGroupOrder[group2]!);
                                    },
                                    groupSeparatorBuilder:
                                        (InstanceMemberStatus group) => Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              switch (group) {
                                                InstanceMemberStatus.omw =>
                                                  'OMW!',
                                                InstanceMemberStatus.yes =>
                                                  'Attending',
                                                InstanceMemberStatus.maybe =>
                                                  'Might be attending',
                                                InstanceMemberStatus.no =>
                                                  'Not attending',
                                                InstanceMemberStatus.invited =>
                                                  'Invited',
                                              },
                                              textAlign: TextAlign.center,
                                              style:
                                                  const TextStyle(fontSize: 18),
                                            )),
                                    itemBuilder: (context, rsvp) {
                                      return ListTile(
                                          leading: rsvpIcons[rsvp.status],
                                          title: Text(rsvp.member!.fullName));
                                    },
                                  )),
                      ])),
          bottomNavigationBar: myUser == null
              ? null
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'RSVP: ',
                    ),
                    ToggleButtons(
                      isSelected: _rsvpSelection,
                      onPressed: (int selectedIndex) async {
                        setState(() {
                          for (int buttonIndex = 0;
                              buttonIndex < _rsvpSelection.length;
                              buttonIndex++) {
                            _rsvpSelection[buttonIndex] =
                                buttonIndex == selectedIndex &&
                                    !_rsvpSelection[selectedIndex];
                          }
                        });

                        final savedRsvp = await rsvpsController.save(
                            instance!,
                            _rsvpSelection[selectedIndex]
                                ? InstanceMemberStatus.values[selectedIndex + 1]
                                : null);

                        // update current event's rsvp list
                        if (rsvps == null) {
                          return;
                        }

                        final existingIndex = rsvps!
                            .indexWhere((rsvp) => rsvp.memberId == myUser.id);

                        setState(() {
                          if (existingIndex == -1) {
                            // append a new rsvp
                            rsvps = [
                              ...rsvps!,
                              savedRsvp!,
                            ];
                          } else if (savedRsvp == null) {
                            // remove existing rsvp
                            rsvps = [
                              ...rsvps!.sublist(0, existingIndex),
                              ...rsvps!.sublist(existingIndex + 1)
                            ];
                          } else {
                            // replace existing rsvp
                            rsvps = [
                              ...rsvps!.sublist(0, existingIndex),
                              savedRsvp,
                              ...rsvps!.sublist(existingIndex + 1)
                            ];
                          }
                        });
                      },
                      children: const [
                        Text('No'),
                        Text('Maybe'),
                        Text('Yes'),
                        Text('OMW')
                      ],
                    ),
                  ],
                )),
    );
  }
}
