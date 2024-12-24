import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/controllers/location.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/controllers/chat.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/screens/chat.dart';
import 'package:squadquest/components/friends_list.dart';
import 'package:squadquest/components/event_live_map.dart';
import 'package:squadquest/components/event_rally_map.dart';
import 'package:squadquest/components/map_preview.dart';
import 'package:squadquest/components/tiles/profile.dart';

final _statusGroupOrder = {
  InstanceMemberStatus.omw: 0,
  InstanceMemberStatus.yes: 1,
  InstanceMemberStatus.maybe: 2,
  InstanceMemberStatus.no: 3,
  InstanceMemberStatus.invited: 4,
};

enum Menu {
  showSetRallyPointMap,
  showLiveMap,
  showChat,
  getLink,
  edit,
  cancel,
  uncancel,
  duplicate
}

typedef RsvpFriend = ({
  InstanceMember rsvp,
  Friend? friendship,
  List<UserProfile>? mutuals
});

final _rsvpsFriendsProvider = FutureProvider.autoDispose
    .family<List<RsvpFriend>, InstanceID>((ref, instanceId) async {
  final session = ref.watch(authControllerProvider);

  if (session == null) {
    return [];
  }

  final eventRsvps = await ref.watch(rsvpsPerEventProvider(instanceId).future);
  final friendsList = await ref.watch(friendsProvider.future);
  final profilesCache = ref.read(profilesCacheProvider.notifier);

  // generate list of rsvp members with friendship status and mutual friends
  final rsvpFriends = await Future.wait(eventRsvps.map((rsvp) async {
    final Friend? friendship = friendsList.firstWhereOrNull((friend) =>
        friend.status == FriendStatus.accepted &&
        ((friend.requesterId == session.user.id &&
                friend.requesteeId == rsvp.memberId) ||
            (friend.requesteeId == session.user.id &&
                friend.requesterId == rsvp.memberId)));

    final mutuals = rsvp.member!.mutuals == null
        ? null
        : await Future.wait(rsvp.member!.mutuals!.map((userId) async {
            final profile = await profilesCache.getById(userId);
            return profile;
          }));

    return (rsvp: rsvp, friendship: friendship, mutuals: mutuals);
  }).toList());

  // filter out non-friend members who haven't responded to their invitation
  return rsvpFriends
      .where((rsvpMember) =>
          rsvpMember.rsvp.memberId == session.user.id ||
          rsvpMember.rsvp.status != InstanceMemberStatus.invited ||
          rsvpMember.friendship != null)
      .toList();
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
  late Timer _refreshEventPointsTimer;

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
            emptyText: 'No friends found who haven\'t already been invited',
            status: FriendStatus.accepted,
            excludeUsers: excludeRsvps
                .map((rsvp) => rsvp.memberId)
                .cast<UserID>()
                .toList()));
  }

  Future<void> _saveRsvp(
      InstanceMemberStatus? status, Instance instance) async {
    try {
      final rsvpsController = ref.read(rsvpsProvider.notifier);
      final savedRsvp = await rsvpsController.save(instance, status);

      logger
          .i('EventDetailsScreen._saveRsvp: status=$status, saved=$savedRsvp');

      // start or stop tracking
      final locationController = ref.read(locationControllerProvider);
      if (status == InstanceMemberStatus.omw) {
        await locationController.startTracking(instance.id!);
      } else {
        await locationController.stopTracking(instance.id!);
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
          content: Text(
            savedRsvp == null
                ? 'You\'ve removed your RSVP'
                : 'You\'ve RSVPed ${savedRsvp.status.name}',
          ),
        ));
      }

      _rsvpSnackbar?.closed.then((reason) {
        _rsvpSnackbar = null;
      });
    } catch (e, st) {
      logger.e("EventDetailsScreen._saveRsvp: error", error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _cancelEvent([bool canceled = true]) async {
    final eventAsync = ref.watch(eventDetailsProvider(widget.instanceId));

    if (eventAsync.value == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              title: Text('${canceled ? 'Cancel' : 'Uncancel'} event?'),
              content: Text(
                  'Are you sure you want to ${canceled ? 'cancel' : 'uncancel'} this event? Guests will be alerted.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            ));

    if (confirmed != true) {
      return;
    }

    await ref
        .read(instancesProvider.notifier)
        .patch(widget.instanceId, {'status': canceled ? 'canceled' : 'live'});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Your event has been ${canceled ? 'canceled' : 'uncanceled'} and guests will be alerted'),
      ));
    }
  }

  void _onMenuSelect(Menu item) async {
    switch (item) {
      case Menu.showSetRallyPointMap:
        _showRallyPointMap();
        break;
      case Menu.showLiveMap:
        _showLiveMap();
        break;
      case Menu.showChat:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => ChatScreen(
              instanceId: widget.instanceId,
              autofocus: true,
            ),
          ),
        );
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
        context.pushNamed('event-edit', pathParameters: {
          'id': widget.instanceId,
        });
        break;
      case Menu.cancel:
        await _cancelEvent();
        break;
      case Menu.uncancel:
        await _cancelEvent(false);
        break;
      case Menu.duplicate:
        context.pushNamed('post-event', queryParameters: {
          'duplicateEventId': widget.instanceId,
        });
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
        enableDrag: false,
        isDismissible: false,
        builder: (BuildContext context) =>
            EventRallyMap(initialRallyPoint: eventAsync.value!.rallyPoint));

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

  Future<dynamic> _showLiveMap() async {
    final eventAsync = ref.watch(eventDetailsProvider(widget.instanceId));

    if (eventAsync.value == null) {
      return;
    }

    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: false,
        builder: (BuildContext context) => EventLiveMap(
            eventId: widget.instanceId,
            rallyPoint: eventAsync.value!.rallyPointLatLng));
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
    final theme = Theme.of(context);

    final session = ref.watch(authControllerProvider);
    final eventAsync = ref.watch(eventDetailsProvider(widget.instanceId));
    final eventRsvpsAsync = session == null
        ? const AsyncValue.data(<InstanceMember>[])
        : ref.watch(rsvpsPerEventProvider(widget.instanceId));
    final rsvpsFriendsAsync = session == null
        ? const AsyncValue.data(<RsvpFriend>[])
        : ref.watch(_rsvpsFriendsProvider(widget.instanceId));
    final latestMessageAsync = session == null
        ? const AsyncValue.data(null)
        : ref.watch(latestChatProvider(widget.instanceId));

    // build RSVP buttons selection from rsvps list
    final List<bool> myRsvpSelection = List.filled(4, false);
    InstanceMemberStatus? myRsvpStatus;

    if (eventRsvpsAsync.hasValue &&
        eventRsvpsAsync.value != null &&
        session != null) {
      myRsvpStatus = eventRsvpsAsync.value!
          .cast<InstanceMember?>()
          .firstWhereOrNull((rsvp) => rsvp?.memberId == session.user.id)
          ?.status;

      for (int buttonIndex = 0;
          buttonIndex < myRsvpSelection.length;
          buttonIndex++) {
        myRsvpSelection[buttonIndex] =
            myRsvpStatus != null && buttonIndex == myRsvpStatus.index - 1;
      }
    }

    // build widgets
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
        PopupMenuButton<Menu>(
          icon: const Icon(Icons.more_vert),
          offset: const Offset(0, 50),
          onSelected: _onMenuSelect,
          itemBuilder: (BuildContext context) => <PopupMenuEntry<Menu>>[
            PopupMenuItem<Menu>(
              value: Menu.showLiveMap,
              enabled: eventAsync.value != null && !eventAsync.isLoading,
              child: const ListTile(
                leading: Icon(Icons.map),
                title: Text('Open live map'),
              ),
            ),
            if (myRsvpStatus != null)
              const PopupMenuItem<Menu>(
                value: Menu.showChat,
                child: ListTile(
                  leading: Icon(Icons.chat),
                  title: Text('Open chat'),
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
                child: ListTile(
                  leading: const Icon(Icons.pin_drop_outlined),
                  title: eventAsync.value?.rallyPoint == null
                      ? const Text('Set rally point')
                      : const Text('Update rally point'),
                ),
              ),
              const PopupMenuItem<Menu>(
                value: Menu.edit,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Edit event'),
                ),
              ),
              PopupMenuItem<Menu>(
                value: eventAsync.value?.status == InstanceStatus.canceled
                    ? Menu.uncancel
                    : Menu.cancel,
                child: ListTile(
                  leading: const Icon(Icons.cancel),
                  title: eventAsync.value?.status == InstanceStatus.canceled
                      ? const Text('Uncancel event')
                      : const Text('Cancel event'),
                ),
              ),
              const PopupMenuItem<Menu>(
                value: Menu.duplicate,
                child: ListTile(
                  leading: Icon(Icons.copy),
                  title: Text('Duplicate event'),
                ),
              ),
            ]
          ],
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _sendInvitations(context, eventRsvpsAsync.value ?? []),
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
                        if (event.status == InstanceStatus.canceled)
                          const ListTile(
                            contentPadding: EdgeInsets.only(bottom: 16),
                            minVerticalPadding: 3,
                            minTileHeight: 0,
                            leading: Icon(Icons.cancel_outlined),
                            textColor: Colors.red,
                            iconColor: Colors.red,
                            title: Text('THIS EVENT HAS BEEN CANCELED'),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    minVerticalPadding: 3,
                                    minTileHeight: 0,
                                    leading: visibilityIcons[event.visibility],
                                    title: switch (event.visibility) {
                                      InstanceVisibility.private =>
                                        const Text('Private event'),
                                      InstanceVisibility.friends =>
                                        const Text('Friends-only event'),
                                      InstanceVisibility.public =>
                                        const Text('Public event'),
                                    },
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    minVerticalPadding: 3,
                                    minTileHeight: 0,
                                    leading: const Icon(Icons.today),
                                    title: Text(eventDateFormat
                                        .format(event.startTimeMin)),
                                  ),
                                  ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      minVerticalPadding: 3,
                                      minTileHeight: 0,
                                      leading: const Icon(Icons.timelapse),
                                      title: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                                '${eventTimeFormat.format(event.startTimeMin)}–${eventTimeFormat.format(event.startTimeMax)}'),
                                            if (event.endTime != null)
                                              Text(eventTimeFormat
                                                  .format(event.endTime!)),
                                          ]),
                                      subtitle: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Meet up between'),
                                            if (event.endTime != null)
                                              const Text('Ends at'),
                                          ])),
                                  if (event.topic != null) ...[
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      minVerticalPadding: 3,
                                      minTileHeight: 0,
                                      leading: const Icon(Icons.topic),
                                      title: Text(event.topic!.name),
                                    ),
                                  ],
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    minVerticalPadding: 3,
                                    minTileHeight: 0,
                                    leading: const Icon(Icons.person_pin),
                                    title: Text(event.createdBy!.displayName),
                                  ),
                                ],
                              ),
                            ),
                            Consumer(builder: (_, ref, child) {
                              final eventPointsAsync = ref.watch(
                                  eventPointsProvider(widget.instanceId));
                              final mapCenter = event.rallyPoint ??
                                  eventPointsAsync.value?.centroid;

                              if (mapCenter == null) {
                                return const SizedBox.shrink();
                              }

                              return Expanded(
                                flex: 1,
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: MapPreview(
                                    location: mapCenter,
                                    showMarker: event.rallyPoint != null,
                                    onTap: _showLiveMap,
                                    overlayText: eventPointsAsync.when(
                                      data: (eventPoints) => eventPoints !=
                                                  null &&
                                              eventPoints.users > 0
                                          ? '${eventPoints.users} live ${eventPoints.users == 1 ? 'user' : 'users'}'
                                          : null,
                                      loading: () => null,
                                      error: (_, __) => null,
                                    ),
                                  ),
                                ),
                              );
                            })
                          ],
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          minVerticalPadding: 3,
                          minTileHeight: 0,
                          leading: const Icon(Icons.place),
                          trailing: const Icon(Icons.open_in_new),
                          title: Text(event.locationDescription),
                          onTap: () {
                            final query = event.rallyPointPlusCode ??
                                event.locationDescription;
                            final uri = Platform.isIOS
                                ? Uri(
                                    scheme: 'comgooglemaps',
                                    host: '',
                                    queryParameters: {'q': query})
                                : Uri(
                                    scheme: 'https',
                                    host: 'maps.google.com',
                                    queryParameters: {'q': query});
                            launchUrl(uri);
                          },
                        ),
                        if (event.link != null) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            minVerticalPadding: 3,
                            minTileHeight: 0,
                            leading: const Icon(Icons.link),
                            trailing: const Icon(Icons.open_in_new),
                            title: Text(
                              event.link.toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => launchUrl(event.link!),
                          ),
                        ],
                        if (event.notes != null &&
                            event.notes!.trim().isNotEmpty) ...[
                          Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(event.notes!)),
                        ],
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
                          if (latestMessageAsync.hasValue) ...[
                            Container(
                              margin: const EdgeInsets.all(5),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withAlpha(65),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (BuildContext context) =>
                                          ChatScreen(
                                              instanceId: widget.instanceId,
                                              latestMessage:
                                                  latestMessageAsync.value!),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    const Text('Latest message:'),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Hero(
                                            tag:
                                                'message-${latestMessageAsync.value!.id}',
                                            child: Material(
                                              type: MaterialType.transparency,
                                              child: ProfileTile(
                                                profile: latestMessageAsync
                                                    .value!.createdBy!,
                                                subtitle: Text(
                                                    latestMessageAsync
                                                        .value!.content),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          rsvpsFriendsAsync.when(
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (error, _) => Text('Error: $error'),
                            data: (rsvpsFriends) => rsvpsFriends.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Text(
                                      'No one has RSVPed to this event yet. Be the first! And then invite your friends with the button below.',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  )
                                : GroupedListView(
                                    primary: false,
                                    shrinkWrap: true,
                                    elements: rsvpsFriends,
                                    groupBy: (RsvpFriend rsvpFriend) =>
                                        rsvpFriend.rsvp.status,
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
                                    itemBuilder: (context, rsvpFriend) {
                                      final isFriendOrSelf =
                                          rsvpFriend.rsvp.memberId! ==
                                                  session.user.id ||
                                              rsvpFriend.friendship != null;
                                      return ListTile(
                                          onTap: isFriendOrSelf
                                              ? () {
                                                  context.pushNamed(
                                                      'profile-view',
                                                      pathParameters: {
                                                        'id': rsvpFriend
                                                            .rsvp.memberId!
                                                      });
                                                }
                                              : null,
                                          leading: !isFriendOrSelf
                                              ? CircleAvatar(
                                                  backgroundColor: theme
                                                      .colorScheme
                                                      .primaryContainer
                                                      .withAlpha(100),
                                                  child: Icon(
                                                    Icons.person_outline,
                                                    color: theme
                                                        .iconTheme.color!
                                                        .withAlpha(100),
                                                  ),
                                                )
                                              : rsvpFriend.rsvp.member!.photo ==
                                                      null
                                                  ? const CircleAvatar(
                                                      child: Icon(Icons.person),
                                                    )
                                                  : CircleAvatar(
                                                      backgroundImage:
                                                          NetworkImage(
                                                              rsvpFriend.rsvp
                                                                  .member!.photo
                                                                  .toString()),
                                                    ),
                                          title: Text(
                                              rsvpFriend
                                                  .rsvp.member!.displayName,
                                              style: TextStyle(
                                                color: isFriendOrSelf
                                                    ? null
                                                    : theme.disabledColor,
                                              )),
                                          subtitle: rsvpFriend.mutuals ==
                                                      null ||
                                                  isFriendOrSelf
                                              ? null
                                              : Text(
                                                  // ignore: prefer_interpolation_to_compose_strings
                                                  'Friend of ${rsvpFriend.mutuals!.map((profile) => profile.displayName).join(', ')}',
                                                  style: TextStyle(
                                                    color: isFriendOrSelf
                                                        ? theme.disabledColor
                                                        : null,
                                                  )),
                                          trailing: rsvpIcons[
                                              rsvpFriend.rsvp.status]);
                                    },
                                  ),
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
        data: (instance) {
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
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                        constraints: BoxConstraints.expand(
                            width: constraints.maxWidth / 4 -
                                (myRsvpSelection.length - 1)),
                        isSelected: myRsvpSelection,
                        onPressed: session == null
                            ? null
                            : (int selectedIndex) async {
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
                                _saveRsvp(status, instance);
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
        },
      ),
    );
  }
}
