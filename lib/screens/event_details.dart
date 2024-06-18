import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/components/friends_list.dart';
import 'package:squadquest/drawer.dart';

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
        builder: (BuildContext context) => const FriendsList(
            title: 'Find friends to invite', status: FriendStatus.accepted));
  }

  Future<void> _saveRsvp(InstanceMemberStatus? status) async {
    final eventRsvpsController =
        ref.read(rsvpsPerEventProvider(widget.instanceId).notifier);

    final savedRsvp = await eventRsvpsController.save(status);

    loggerNoStack
        .i('EventDetailsScreen._saveRsvp: status=$status, saved=$savedRsvp');

    if (_rsvpSnackbar != null) {
      try {
        _rsvpSnackbar!.close();
      } catch (error) {
        logger.e(error);
      }
      _rsvpSnackbar = null;
    }

    if (!context.mounted) return;

    _rsvpSnackbar = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(savedRsvp == null
          ? 'You\'ve removed your RSVP'
          : 'You\'ve RSVPed ${savedRsvp.status.name}'),
    ));

    _rsvpSnackbar?.closed.then((reason) {
      _rsvpSnackbar = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final eventAsync = ref.watch(eventDetailsProvider(widget.instanceId));
    final eventRsvpsAsync = ref.watch(rsvpsPerEventProvider(widget.instanceId));

    // build RSVP buttons selection from rsvps list
    List<bool> myRsvpSelection = List.filled(4, true);
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
          drawer: context.canPop() ? null : const AppDrawer(),
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
                                                  .compareTo(_statusGroupOrder[
                                                      group2]!);
                                            },
                                            groupSeparatorBuilder:
                                                (InstanceMemberStatus group) =>
                                                    Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
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
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 18),
                                                        )),
                                            itemBuilder: (context, rsvp) {
                                              return ListTile(
                                                  leading:
                                                      rsvpIcons[rsvp.status],
                                                  title: Text(
                                                      rsvp.member!.fullName));
                                            },
                                          ))),
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
                  ))),
    );
  }
}
