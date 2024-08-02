import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/controllers/location.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/components/friends_list.dart';
import 'package:squadquest/components/event_live_map.dart';
import 'package:squadquest/components/event_rally_map.dart';
import 'package:url_launcher/url_launcher.dart';

final _statusGroupOrder = {
  InstanceMemberStatus.omw: 0,
  InstanceMemberStatus.yes: 1,
  InstanceMemberStatus.maybe: 2,
  InstanceMemberStatus.no: 3,
  InstanceMemberStatus.invited: 4,
};

enum Menu { showSetRallyPointMap, showLiveMap, getLink, edit, cancel, uncancel }

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
  MapLibreMapController? _mapController;
  Symbol? _rallyPointSymbol;
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

  Future<void> _saveRsvp(InstanceMemberStatus? status) async {
    final eventRsvpsController =
        ref.read(rsvpsPerEventProvider(widget.instanceId).notifier);

    final savedRsvp = await eventRsvpsController.save(status);

    logger.i('EventDetailsScreen._saveRsvp: status=$status, saved=$savedRsvp');

    // start or stop tracking
    final locationController = ref.read(locationControllerProvider);
    if (status == InstanceMemberStatus.omw) {
      await locationController.startTracking(widget.instanceId);
    } else {
      await locationController.stopTracking(widget.instanceId);
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

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onMapStyleLoaded(Instance event) async {
    await _mapController!.addImage(
        'flag-marker',
        (await rootBundle.load('assets/symbols/flag-marker.png'))
            .buffer
            .asUint8List());

    // add rally point
    await _refreshMap(event);
  }

  Future<void> _refreshMap(Instance event) async {
    if (event.rallyPoint == null) {
      if (_rallyPointSymbol != null) {
        await _mapController!.removeSymbol(_rallyPointSymbol!);
        _rallyPointSymbol = null;
      }
    } else {
      final latLng = LatLng(event.rallyPoint!.lat, event.rallyPoint!.lon);

      final options = SymbolOptions(
          geometry: latLng,
          iconImage: 'flag-marker',
          iconSize: kIsWeb ? 0.125 : 0.25,
          iconAnchor: 'bottom-left');

      if (_rallyPointSymbol == null) {
        _rallyPointSymbol = await _mapController!.addSymbol(options);
      } else {
        await _mapController!.updateSymbol(_rallyPointSymbol!, options);
      }

      await _mapController!.animateCamera(CameraUpdate.newLatLng(latLng));
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
    final theme = Theme.of(context);

    final session = ref.watch(authControllerProvider);
    final eventAsync = ref.watch(eventDetailsProvider(widget.instanceId));
    final eventRsvpsAsync = ref.watch(rsvpsPerEventProvider(widget.instanceId));
    final rsvpsFriendsAsync =
        ref.watch(_rsvpsFriendsProvider(widget.instanceId));

    // refresh map when event changes
    ref.listen(eventDetailsProvider(widget.instanceId), (_, event) async {
      if (!event.isLoading && _mapController != null && event.value != null) {
        await _refreshMap(event.value!);
      }
    });

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
        showDrawer: !context.canPop(),
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
              ]
            ],
          ),
        ],
        floatingActionButton: FloatingActionButton(
          onPressed: () =>
              _sendInvitations(context, eventRsvpsAsync.value ?? []),
          child: const Icon(Icons.mail),
        ),
        locationSharingAvailableEvent:
            eventAsync.value?.getTimeGroup() == InstanceTimeGroup.past ||
                    myRsvpStatus != InstanceMemberStatus.omw
                ? null
                : eventAsync.value!.id,
        body: eventAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
            data:
                (event) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (event.bannerPhoto != null) ...[
                            ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 175),
                                child: Image.network(
                                    event.bannerPhoto!.toString(),
                                    fit: BoxFit.cover)),
                          ],
                          Expanded(
                              child: RefreshIndicator(
                                  onRefresh: () async {
                                    ref.invalidate(eventDetailsProvider(
                                        widget.instanceId));
                                    ref.invalidate(rsvpsPerEventProvider(
                                        widget.instanceId));
                                  },
                                  child: SingleChildScrollView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                          flex: 2,
                                                          child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                if (event
                                                                        .status ==
                                                                    InstanceStatus
                                                                        .canceled)
                                                                  const Text(
                                                                      'Status: CANCELED'),
                                                                Text(
                                                                    'Starting between: ${eventTimeFormat.format(event.startTimeMin)}–${eventTimeFormat.format(event.startTimeMax)}'),
                                                                Text(
                                                                    'Date: ${eventDateFormat.format(event.startTimeMin)}'),
                                                                Text(
                                                                    'Topic: ${event.topic?.name}'),
                                                                Text(
                                                                    'Posted by: ${event.createdBy?.displayName}'),
                                                                Text(
                                                                    'Visibility: ${event.visibility.name}'),
                                                                Text(
                                                                    'Location: ${event.locationDescription}'),
                                                                if (event
                                                                        .link !=
                                                                    null) ...[
                                                                  RichText(
                                                                      text: TextSpan(
                                                                          children: [
                                                                        const TextSpan(
                                                                            text:
                                                                                'Link: '),
                                                                        TextSpan(
                                                                          text: event
                                                                              .link
                                                                              .toString(),
                                                                          style:
                                                                              const TextStyle(
                                                                            color:
                                                                                Colors.blue,
                                                                            decoration:
                                                                                TextDecoration.underline,
                                                                          ),
                                                                          recognizer: TapGestureRecognizer()
                                                                            ..onTap =
                                                                                () => launchUrl(event.link!),
                                                                        )
                                                                      ]))
                                                                ],
                                                                if (event.notes !=
                                                                        null &&
                                                                    event.notes!
                                                                        .trim()
                                                                        .isNotEmpty) ...[
                                                                  Text(
                                                                      'Notes: ${event.notes}')
                                                                ]
                                                              ])),
                                                      if (event.rallyPoint !=
                                                          null)
                                                        Expanded(
                                                            flex: 1,
                                                            child: AspectRatio(
                                                                aspectRatio: 1,
                                                                child: Consumer(
                                                                    builder: (_,
                                                                        ref,
                                                                        child) {
                                                                      final eventPointsAsync =
                                                                          ref.watch(
                                                                              eventPointsProvider(widget.instanceId));
                                                                      return Stack(
                                                                          children: [
                                                                            child!,
                                                                            const Positioned(
                                                                                top: 0,
                                                                                right: 0,
                                                                                child: IgnorePointer(
                                                                                    child: Icon(
                                                                                  Icons.zoom_in,
                                                                                  // color: Colors.red,
                                                                                  size: 32,
                                                                                ))),
                                                                            eventPointsAsync.when(
                                                                              data: (eventPoints) => eventPoints == null || eventPoints.users == 0
                                                                                  ? const SizedBox.shrink()
                                                                                  : Positioned(
                                                                                      bottom: 0,
                                                                                      left: 0,
                                                                                      right: 0,
                                                                                      child: IgnorePointer(
                                                                                          child: Container(
                                                                                              color: Colors.black.withOpacity(0.5),
                                                                                              child: Text(
                                                                                                '${eventPoints.users} live ${eventPoints.users == 1 ? 'user' : 'users'}',
                                                                                                style: const TextStyle(fontSize: 12),
                                                                                                textAlign: TextAlign.center,
                                                                                              )))),
                                                                              loading: () => const SizedBox.shrink(),
                                                                              error: (_, __) => const SizedBox.shrink(),
                                                                            )
                                                                          ]);
                                                                    },
                                                                    child:
                                                                        MapLibreMap(
                                                                      styleString:
                                                                          'https://api.maptiler.com/maps/08847b31-fc27-462a-b87e-2e8d8a700529/style.json?key=XYHvSt2RxwZPOxjSj98n',

                                                                      // listeners
                                                                      onMapCreated:
                                                                          _onMapCreated,
                                                                      onStyleLoadedCallback:
                                                                          () =>
                                                                              _onMapStyleLoaded(event),
                                                                      onMapClick:
                                                                          (_, __) =>
                                                                              _showLiveMap(),

                                                                      // disable all interaction
                                                                      dragEnabled:
                                                                          false,
                                                                      compassEnabled:
                                                                          false,
                                                                      zoomGesturesEnabled:
                                                                          false,
                                                                      rotateGesturesEnabled:
                                                                          false,
                                                                      tiltGesturesEnabled:
                                                                          false,
                                                                      scrollGesturesEnabled:
                                                                          false,
                                                                      doubleClickZoomEnabled:
                                                                          false,

                                                                      // hide attribution in mini view
                                                                      attributionButtonPosition:
                                                                          AttributionButtonPosition
                                                                              .bottomRight,
                                                                      attributionButtonMargins: const Point(
                                                                          -100,
                                                                          -100),

                                                                      // set initial camera position to rally point
                                                                      initialCameraPosition:
                                                                          CameraPosition(
                                                                        target: LatLng(
                                                                            event.rallyPoint!.lat,
                                                                            event.rallyPoint!.lon),
                                                                        zoom:
                                                                            11.75,
                                                                      ),
                                                                    ))))
                                                    ]),
                                                rsvpsFriendsAsync.when(
                                                    loading: () => const Center(
                                                        child:
                                                            CircularProgressIndicator()),
                                                    error: (error, _) =>
                                                        Text('Error: $error'),
                                                    data: (rsvpsFriends) =>
                                                        rsvpsFriends.isEmpty
                                                            ? const Padding(
                                                                padding:
                                                                    EdgeInsets
                                                                        .all(
                                                                            32),
                                                                child: Text(
                                                                  'No one has RSVPed to this event yet. Be the first! And then invite your friends with the button below.',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          20),
                                                                ),
                                                              )
                                                            : GroupedListView(
                                                                primary: false,
                                                                shrinkWrap:
                                                                    true,
                                                                elements:
                                                                    rsvpsFriends,
                                                                groupBy: (RsvpFriend
                                                                        rsvpFriend) =>
                                                                    rsvpFriend
                                                                        .rsvp
                                                                        .status,
                                                                groupComparator:
                                                                    (group1,
                                                                        group2) {
                                                                  return _statusGroupOrder[
                                                                          group1]!
                                                                      .compareTo(
                                                                          _statusGroupOrder[
                                                                              group2]!);
                                                                },
                                                                groupSeparatorBuilder: (InstanceMemberStatus
                                                                        group) =>
                                                                    Padding(
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            8.0),
                                                                        child:
                                                                            Text(
                                                                          switch (
                                                                              group) {
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
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                          style:
                                                                              const TextStyle(fontSize: 18),
                                                                        )),
                                                                itemBuilder:
                                                                    (context,
                                                                        rsvpFriend) {
                                                                  final isFriendOrSelf = rsvpFriend
                                                                              .rsvp
                                                                              .memberId! ==
                                                                          session!
                                                                              .user
                                                                              .id ||
                                                                      rsvpFriend
                                                                              .friendship !=
                                                                          null;
                                                                  return ListTile(
                                                                      onTap: isFriendOrSelf
                                                                          ? () {
                                                                              context.pushNamed('profile-view', pathParameters: {
                                                                                'id': rsvpFriend.rsvp.memberId!
                                                                              });
                                                                            }
                                                                          : null,
                                                                      leading: !isFriendOrSelf
                                                                          ? CircleAvatar(
                                                                              backgroundColor: theme.colorScheme.primaryContainer.withAlpha(100),
                                                                              child: Icon(
                                                                                Icons.person_outline,
                                                                                color: theme.iconTheme.color!.withAlpha(100),
                                                                              ),
                                                                            )
                                                                          : rsvpFriend.rsvp.member!.photo == null
                                                                              ? const CircleAvatar(
                                                                                  child: Icon(Icons.person),
                                                                                )
                                                                              : CircleAvatar(
                                                                                  backgroundImage: NetworkImage(rsvpFriend.rsvp.member!.photo.toString()),
                                                                                ),
                                                                      title: Text(rsvpFriend.rsvp.member!.displayName,
                                                                          style: TextStyle(
                                                                            color: isFriendOrSelf
                                                                                ? null
                                                                                : theme.disabledColor,
                                                                          )),
                                                                      subtitle: rsvpFriend.mutuals == null || isFriendOrSelf
                                                                          ? null
                                                                          : Text(
                                                                              // ignore: prefer_interpolation_to_compose_strings
                                                                              'Friend of ${rsvpFriend.mutuals!.map((profile) => profile.displayName).join(', ')}',
                                                                              style: TextStyle(
                                                                                color: isFriendOrSelf ? theme.disabledColor : null,
                                                                              )),
                                                                      trailing: rsvpIcons[rsvpFriend.rsvp.status]);
                                                                },
                                                              )),
                                              ])))))
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
