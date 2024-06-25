import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:go_router/go_router.dart';
import 'package:squadquest/app_scaffold.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/location.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/components/friends_list.dart';
import 'package:squadquest/components/event_live_map.dart';
import 'package:squadquest/components/event_rally_map.dart';

final _statusGroupOrder = {
  InstanceMemberStatus.omw: 0,
  InstanceMemberStatus.yes: 1,
  InstanceMemberStatus.maybe: 2,
  InstanceMemberStatus.no: 3,
  InstanceMemberStatus.invited: 4,
};

enum Menu { showSetRallyPointMap, showLiveMap, getLink, edit, cancel }

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
  List<InstanceMember>? rsvps;
  ScaffoldFeatureController? _rsvpSnackbar;

  void _sendInvitations(
      BuildContext context, List<InstanceMember> excludeRsvps) async {
    final inviteUserIds = await _showInvitationDialog(excludeRsvps);

    if (inviteUserIds == null || inviteUserIds.length == 0) {
      return;
    }

    final sentInvitations = await ref
        .read(rsvpsProvider.notifier)
        .invite(widget.instanceId, inviteUserIds);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Sent ${sentInvitations.length == 1 ? 'invitation' : 'invitations'} to ${sentInvitations.length} ${sentInvitations.length == 1 ? 'friend' : 'friends'}'),
    ));
  }

  Future<dynamic> _showInvitationDialog(
      List<InstanceMember> excludeRsvps) async {
    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => FriendsList(
            title: 'Find friends to invite',
            status: FriendStatus.accepted,
            excludeUsers: excludeRsvps
                .map((rsvp) => rsvp.memberId)
                .cast<UserID>()
                .toList()));
  }

  Future<void> _saveRsvp(InstanceMemberStatus? status) async {
    final eventRsvpsController =
        ref.read(rsvpsPerEventProvider(widget.instanceId).notifier);

    final savedRsvp = await eventRsvpsController.save(status);

    logger.i('EventDetailsScreen._saveRsvp: status=$status, saved=$savedRsvp');

    // start or stop tracking
    final locationService = ref.read(locationServiceProvider);
    if (status == InstanceMemberStatus.omw) {
      await locationService.startTracking(widget.instanceId);
    } else {
      await locationService.stopTracking(widget.instanceId);
    }

    if (_rsvpSnackbar != null) {
      try {
        _rsvpSnackbar!.close();
      } catch (error) {
        loggerWithStack.e(error);
      }
      _rsvpSnackbar = null;
    }

    if (mounted) {
      _rsvpSnackbar = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(savedRsvp == null
            ? 'You\'ve removed your RSVP'
            : 'You\'ve RSVPed ${savedRsvp.status.name}'),
      ));
    }

    _rsvpSnackbar?.closed.then((reason) {
      _rsvpSnackbar = null;
    });
  }

  void _onMenuSelect(Menu item) async {
    switch (item) {
      case Menu.showSetRallyPointMap:
        _showRallyPointMap();
        break;
      case Menu.showLiveMap:
        _showLiveMap();
        break;
      case Menu.getLink:
        await Clipboard.setData(ClipboardData(
            text: "https://squadquest.app/events/${widget.instanceId}"));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Event link copied to clipboard'),
          ));
        }
        break;
      case Menu.edit:
        logger.i('Edit event');
        break;
      case Menu.cancel:
        logger.i('Cancel event');
        break;
    }
  }

  Future<dynamic> _showRallyPointMap() async {
    final eventAsync = ref.watch(eventDetailsProvider(widget.instanceId));

    if (eventAsync.value == null) {
      return;
    }

    final updatedRallyPoint = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => EventRallyMap(
            eventId: widget.instanceId,
            initialRallyPoint: eventAsync.value!.rallyPointLatLng));

    if (updatedRallyPoint == null) {
      return;
    }

    logger.d({'updatedRallyPoint': updatedRallyPoint});

    await ref.read(instancesProvider.notifier).patch(widget.instanceId, {
      'rally_point':
          'POINT(${updatedRallyPoint.longitude} ${updatedRallyPoint.latitude})',
    });

    ref.invalidate(eventDetailsProvider(widget.instanceId));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Rally point updated!'),
      ));
    }
  }

  Future<dynamic> _showLiveMap() async {
    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) =>
            EventLiveMap(eventId: widget.instanceId));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final eventAsync = ref.watch(eventDetailsProvider(widget.instanceId));
    final eventRsvpsAsync = ref.watch(rsvpsPerEventProvider(widget.instanceId));

    // build RSVP buttons selection from rsvps list
    List<bool> myRsvpSelection = List.filled(4, false);
    if (eventRsvpsAsync.hasValue &&
        eventRsvpsAsync.value != null &&
        session != null) {
      final myRsvp = eventRsvpsAsync.value!.cast<InstanceMember?>().firstWhere(
          (rsvp) => rsvp?.memberId == session.user.id,
          orElse: () => null);

      for (int buttonIndex = 0;
          buttonIndex < myRsvpSelection.length;
          buttonIndex++) {
        myRsvpSelection[buttonIndex] =
            myRsvp != null && buttonIndex == myRsvp.status.index - 1;
      }
    }

    // build widgets
    return AppScaffold(
        showDrawer: !context.canPop(),
        title: eventAsync.when(
          data: (event) => event.title,
          loading: () => '',
          error: (_, __) => 'Error loading event details',
        ),
        actions: [
          PopupMenuButton<Menu>(
            icon: const Icon(Icons.more_vert),
            onSelected: _onMenuSelect,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<Menu>>[
              const PopupMenuItem<Menu>(
                value: Menu.showLiveMap,
                child: ListTile(
                  leading: Icon(Icons.map),
                  title: Text('Open live map'),
                ),
              ),
              const PopupMenuItem<Menu>(
                value: Menu.getLink,
                child: ListTile(
                  leading: Icon(Icons.link_outlined),
                  title: Text('Get link'),
                ),
              ),
              if (eventAsync.value?.createdById == session?.user.id) ...[
                const PopupMenuDivider(),
                PopupMenuItem<Menu>(
                  value: Menu.showSetRallyPointMap,
                  enabled: eventAsync.value != null && !eventAsync.isLoading,
                  child: const ListTile(
                    leading: Icon(Icons.pin_drop_outlined),
                    title: Text('Set rally point'),
                  ),
                ),
                // const PopupMenuItem<Menu>(
                //   value: Menu.edit,
                //   child: ListTile(
                //     leading: Icon(Icons.delete_outline),
                //     title: Text('Edit event'),
                //   ),
                // ),
                // const PopupMenuItem<Menu>(
                //   value: Menu.cancel,
                //   child: ListTile(
                //     leading: Icon(Icons.cancel),
                //     title: Text('Cancel event'),
                //   ),
                // ),
              ]
            ],
          ),
        ],
        floatingActionButton: FloatingActionButton(
          onPressed: () =>
              _sendInvitations(context, eventRsvpsAsync.value ?? []),
          child: const Icon(Icons.mail),
        ),
        bodyPadding: const EdgeInsets.all(16),
        body: eventAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
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
                          child: eventRsvpsAsync.when(
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (error, _) => Text('Error: $error'),
                              data: (eventRsvps) => eventRsvps.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Text(
                                        'No one has RSVPed to this event yet. Be the first! And then invite your friends with the button below.',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                    )
                                  : GroupedListView(
                                      elements: eventRsvps,
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
                                                      const EdgeInsets.all(8.0),
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
                                                      InstanceMemberStatus.no =>
                                                        'Not attending',
                                                      InstanceMemberStatus
                                                            .invited =>
                                                        'Invited',
                                                    },
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        fontSize: 18),
                                                  )),
                                      itemBuilder: (context, rsvp) {
                                        return ListTile(
                                            leading: rsvpIcons[rsvp.status],
                                            title: Text(rsvp.member!.fullName));
                                      },
                                    ))),
                    ])),
        bottomNavigationBar: session == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 16),
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
                                  (myRsvpSelection.length - 1)),
                          isSelected: myRsvpSelection,
                          onPressed: (int selectedIndex) async {
                            // update button state (will not apply to UI until action updates RSVP list though)
                            for (int buttonIndex = 0;
                                buttonIndex < myRsvpSelection.length;
                                buttonIndex++) {
                              myRsvpSelection[buttonIndex] =
                                  buttonIndex == selectedIndex &&
                                      !myRsvpSelection[selectedIndex];
                            }

                            // convert index and button state to desired status
                            InstanceMemberStatus? status =
                                myRsvpSelection[selectedIndex]
                                    ? InstanceMemberStatus
                                        .values[selectedIndex + 1]
                                    : null;

                            // save
                            _saveRsvp(status);
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
                )));
  }
}
