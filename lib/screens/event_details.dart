import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/chat.dart';
import 'package:squadquest/components/event_rally_map.dart';
import 'package:squadquest/components/friends_list.dart';

import 'event_details/providers.dart';
import 'event_details/map.dart';
import 'event_details/menu.dart';
import 'event_details/header.dart';
import 'event_details/rsvp.dart';
import 'event_details/attendees.dart';
import 'event_details/chat_preview.dart';

class EventDetailsScreen extends ConsumerStatefulWidget {
  final InstanceID instanceId;

  const EventDetailsScreen({super.key, required this.instanceId});

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  late Timer _refreshEventPointsTimer;

  void _sendInvitations(List<InstanceMember> excludeRsvps) async {
    final inviteUserIds = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => FriendsList(
            title: 'Find friends to invite',
            emptyText: 'No friends found who haven\'t already been invited',
            status: FriendStatus.accepted,
            excludeUsers: excludeRsvps
                .map((rsvp) => rsvp.memberId)
                .whereType<String>()
                .toList()));

    if (inviteUserIds == null || inviteUserIds.isEmpty) {
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

  Future<void> _showRallyPointMap(Instance event) async {
    final updatedRallyPoint = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: false,
        isDismissible: false,
        builder: (BuildContext context) =>
            EventRallyMap(initialRallyPoint: event.rallyPoint));

    await ref.read(instancesProvider.notifier).patch(widget.instanceId, {
      'rally_point': updatedRallyPoint == null
          ? null
          : 'POINT(${updatedRallyPoint.lon} ${updatedRallyPoint.lat})',
    });

    ref.invalidate(eventDetailsProvider(widget.instanceId));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Rally point ${updatedRallyPoint == null ? 'cleared' : 'updated'}!'),
      ));
    }
  }

  @override
  void initState() {
    super.initState();

    // listen for location updates
    _refreshEventPointsTimer = Timer.periodic(const Duration(seconds: 60),
        (Timer t) => ref.invalidate(eventPointsProvider(widget.instanceId)));
  }

  @override
  void dispose() {
    _refreshEventPointsTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final eventAsync = ref.watch(eventDetailsProvider(widget.instanceId));
    final eventRsvpsAsync = session == null
        ? const AsyncValue.data(<InstanceMember>[])
        : ref.watch(rsvpsPerEventProvider(widget.instanceId));
    final rsvpsFriendsAsync = session == null
        ? const AsyncValue.data(<RsvpFriend>[])
        : ref.watch(rsvpsFriendsProvider(widget.instanceId));
    final latestMessageAsync = session == null
        ? const AsyncValue.data(null)
        : ref.watch(latestChatProvider(widget.instanceId));

    // build RSVP status from rsvps list
    InstanceMemberStatus? myRsvpStatus;
    if (eventRsvpsAsync.hasValue &&
        eventRsvpsAsync.value != null &&
        session != null) {
      myRsvpStatus = eventRsvpsAsync.value!
          .cast<InstanceMember?>()
          .firstWhereOrNull((rsvp) => rsvp?.memberId == session.user.id)
          ?.status;
    }

    return AppScaffold(
      title: eventAsync.when(
        data: (event) => event.title,
        loading: () => '',
        error: (_, __) => 'Error loading event details',
      ),
      titleStyle: eventAsync.valueOrNull?.status == InstanceStatus.canceled
          ? const TextStyle(
              decoration: TextDecoration.lineThrough,
            )
          : null,
      actions: [
        if (eventAsync.hasValue)
          EventDetailsMenu(
            event: eventAsync.value!,
            instanceId: widget.instanceId,
            currentUserId: session?.user.id,
            myRsvpStatus: myRsvpStatus,
            onShowRallyPointMap: () => _showRallyPointMap(eventAsync.value!),
            onShowLiveMap: () {},
          ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _sendInvitations(eventRsvpsAsync.value ?? []),
        child: const Icon(Icons.person_add),
      ),
      locationSharingAvailableEvent:
          eventAsync.value?.getTimeGroup() == InstanceTimeGroup.past ||
                  myRsvpStatus != InstanceMemberStatus.omw
              ? null
              : eventAsync.value!.id,
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (event) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (event.bannerPhoto != null) ...[
              ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 175),
                  child: Image.network(event.bannerPhoto!.toString(),
                      fit: BoxFit.cover)),
            ],
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(eventDetailsProvider(widget.instanceId));
                  ref.invalidate(rsvpsPerEventProvider(widget.instanceId));
                  ref.invalidate(latestChatProvider(widget.instanceId));
                  ref.invalidate(chatProvider(widget.instanceId));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: EventDetailsHeader(event: event),
                            ),
                            Expanded(
                              flex: 1,
                              child: EventDetailsMap(
                                event: event,
                                instanceId: widget.instanceId,
                                onShowRallyPointMap: () =>
                                    _showRallyPointMap(event),
                              ),
                            ),
                          ],
                        ),
                        if (session == null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                  child: ElevatedButton(
                                      child: const Text(
                                          'Join SquadQuest to RSVP to this event'),
                                      onPressed: () {
                                        context.goNamed('login',
                                            queryParameters: {
                                              'redirect':
                                                  '/events/${widget.instanceId}'
                                            });
                                      })))
                        else ...[
                          if (latestMessageAsync.hasValue &&
                              latestMessageAsync.value != null)
                            EventDetailsChatPreview(
                              latestMessage: latestMessageAsync.value!,
                              instanceId: widget.instanceId,
                            ),
                          if (rsvpsFriendsAsync.hasValue)
                            EventDetailsAttendees(
                              rsvpsFriends: rsvpsFriendsAsync.value ?? [],
                              currentUserId: session.user.id,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
      bottomNavigationBar: eventAsync.whenOrNull(
        data: (event) => EventDetailsRSVP(
          event: event,
          currentStatus: myRsvpStatus,
          isLoggedIn: session != null,
        ),
      ),
    );
  }
}
