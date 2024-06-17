import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';

import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/components/friends_list.dart';

final _statusGroupOrder = {
  InstanceMemberStatus.omw: 0,
  InstanceMemberStatus.yes: 1,
  InstanceMemberStatus.maybe: 2,
  InstanceMemberStatus.no: 3,
  InstanceMemberStatus.invited: 4,
};

final eventDetailsProvider = FutureProvider.autoDispose
    .family<Instance, InstanceID>((ref, instanceId) async {
  final instancesController = ref.watch(instancesProvider.notifier);
  return instancesController.getById(instanceId);
});

class EventDetailsScreen extends ConsumerStatefulWidget {
  final InstanceID instanceId;

  const EventDetailsScreen({super.key, required this.instanceId});

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  // Instance? instance;
  late StreamSubscription rsvpSubscription;
  final List<bool> _rsvpSelection = [false, false, false, false];
  List<InstanceMember>? rsvps;
  ScaffoldFeatureController? _rsvpSnackbar;

  void _sendInvitations(BuildContext context) async {
    final inviteUserIds = await _showInvitationDialog();

    if (inviteUserIds == null || inviteUserIds.length == 0) {
      return;
    }

    final sentInvitations = await ref
        .read(rsvpsProvider.notifier)
        .invite(widget.instanceId, inviteUserIds);

    setState(() {
      rsvps = [
        ...rsvps!,
        ...sentInvitations,
      ];
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Sent ${sentInvitations.length == 1 ? 'invitation' : 'invitations'} to ${sentInvitations.length} ${sentInvitations.length == 1 ? 'friend' : 'friends'}'),
    ));
  }

  Future<dynamic> _showInvitationDialog() async {
    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) =>
            const FriendsList(status: FriendStatus.accepted));
  }

  @override
  void initState() {
    super.initState();

    final session = ref.read(authControllerProvider);
    log('EventDetailsScreen.initState: rsvps=$rsvps, session=${session == null ? 'no' : 'yes'}');

    if (session != null) {
      loadRsvps(ref, session);
    }
  }

  void loadRsvps(WidgetRef ref, Session session) {
    log('EventDetailsScreen.loadRsvps: rsvps=$rsvps');
    final UserID myUserId = session.user.id;

    rsvpSubscription = ref
        .read(rsvpsProvider.notifier)
        .subscribeByInstance(widget.instanceId, (rsvps) {
      setState(() {
        this.rsvps = rsvps;
      });

      final myRsvp = rsvps
          .cast<InstanceMember?>()
          .firstWhere((rsvp) => rsvp?.memberId == myUserId, orElse: () => null);

      setState(() {
        for (int buttonIndex = 0;
            buttonIndex < _rsvpSelection.length;
            buttonIndex++) {
          _rsvpSelection[buttonIndex] =
              myRsvp != null && buttonIndex == myRsvp.status.index - 1;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final eventAsync = ref.watch(eventDetailsProvider(widget.instanceId));
    final rsvpsController = ref.read(rsvpsProvider.notifier);

    log('EventDetailsScreen.build: rsvps=$rsvps, session=${session == null ? 'no' : 'yes'}');

    return SafeArea(
      child: Scaffold(
          appBar: AppBar(
              title: eventAsync.when(
            data: (event) => Text(event.title),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const Text('Error loading event details'),
          )),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _sendInvitations(context),
            child: const Icon(Icons.mail),
          ),
          body: Padding(
              padding: const EdgeInsets.all(16),
              child: eventAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text(error.toString())),
                  data: (event) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Location: ${event.locationDescription}'),
                            Text('Topic: ${event.topic?.name}'),
                            Text('Posted by: ${event.createdBy?.fullName}'),
                            Text('Visibility: ${event.visibility.name}'),
                            Text(
                                'Date: ${eventDateFormat.format(event.startTimeMin)}'),
                            Text(
                                'Starting between: ${eventTimeFormat.format(event.startTimeMin)}–${eventTimeFormat.format(event.startTimeMax)}'),
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
                                            (InstanceMemberStatus group) =>
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Text(
                                                      switch (group) {
                                                        InstanceMemberStatus
                                                              .omw =>
                                                          'OMW!',
                                                        InstanceMemberStatus
                                                              .yes =>
                                                          'Attending',
                                                        InstanceMemberStatus
                                                              .maybe =>
                                                          'Might be attending',
                                                        InstanceMemberStatus
                                                              .no =>
                                                          'Not attending',
                                                        InstanceMemberStatus
                                                              .invited =>
                                                          'Invited',
                                                      },
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                          fontSize: 18),
                                                    )),
                                        itemBuilder: (context, rsvp) {
                                          return ListTile(
                                              leading: rsvpIcons[rsvp.status],
                                              title:
                                                  Text(rsvp.member!.fullName));
                                        },
                                      )),
                          ]))),
          bottomNavigationBar: session == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      const Text(
                        'RSVP: ',
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: LayoutBuilder(builder: (context, constraints) {
                          return ToggleButtons(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8)),
                            constraints: BoxConstraints.expand(
                                width: constraints.maxWidth / 4 -
                                    (_rsvpSelection.length - 1)),
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
                                  widget.instanceId,
                                  _rsvpSelection[selectedIndex]
                                      ? InstanceMemberStatus
                                          .values[selectedIndex + 1]
                                      : null);

                              // update current event's rsvp list
                              if (rsvps != null) {
                                final existingIndex = rsvps!.indexWhere(
                                    (rsvp) => rsvp.memberId == session.user.id);

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
                              }

                              if (!context.mounted) return;

                              if (_rsvpSnackbar != null) {
                                _rsvpSnackbar!.close();
                              }

                              _rsvpSnackbar = ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(savedRsvp == null
                                    ? 'You\'ve removed your RSVP'
                                    : 'You\'ve RSVPed ${savedRsvp.status.name}'),
                              ));

                              _rsvpSnackbar?.closed.then((reason) {
                                _rsvpSnackbar = null;
                              });
                            },
                            children: const [
                              Text('No'),
                              Text('Maybe'),
                              Text('Yes'),
                              Text('OMW')
                            ],
                          );
                        }),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ))),
    );
  }

  @override
  void dispose() {
    log('EventDetailsScreen.dispose: rsvpSubscription=$rsvpSubscription');
    rsvpSubscription.cancel();
    super.dispose();
  }
}
