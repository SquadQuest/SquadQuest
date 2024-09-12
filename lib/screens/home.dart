import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grouped_list/grouped_list.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/topic_subscriptions.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/components/tiles/instance.dart';

enum EventsTab {
  invitedAndSubscribed,
  awaitingMyResponse,
  imGoing,
  imHosting,
  allPublic
}

final _goingStatuses = [
  InstanceMemberStatus.maybe,
  InstanceMemberStatus.yes,
  InstanceMemberStatus.omw,
];

final _eventsTabProvider =
    StateProvider<EventsTab>((ref) => EventsTab.invitedAndSubscribed);

final _filteredEventsProvider = FutureProvider<
    ({
      int awaitingMyResponseCount,
      List<Instance> events,
      List<TopicID> topics
    })>((ref) async {
  final session = ref.read(authControllerProvider);
  final events = await ref.watch(instancesProvider.future);
  final topics = await ref.watch(topicSubscriptionsProvider.future);
  final rsvpsList = ref.watch(rsvpsProvider);
  final eventsTab = ref.watch(_eventsTabProvider);
  final now = DateTime.now();

  return (
    awaitingMyResponseCount: events.where((event) {
      final rsvp = rsvpsList.value
          ?.firstWhereOrNull((rsvp) => rsvp.instanceId == event.id);
      return rsvp?.status == InstanceMemberStatus.invited &&
          event.getTimeGroup(now) != InstanceTimeGroup.past;
    }).length,
    events: events.where((event) {
      final rsvp = rsvpsList.value
          ?.firstWhereOrNull((rsvp) => rsvp.instanceId == event.id);

      // never show draft events unless you created it
      if (event.status == InstanceStatus.draft &&
          event.createdById != session?.user.id) {
        return false;
      }

      switch (eventsTab) {
        case EventsTab.invitedAndSubscribed:
          // always show events you created
          if (event.createdById == session?.user.id) {
            return true;
          }

          // always show events you have an invitation/RSVP to
          if (rsvp != null) {
            return true;
          }

          // don't show canceled events if none of the above passed
          if (event.status != InstanceStatus.live) {
            return false;
          }

          // don't show public events unless you're subscribed to the topic
          if (eventsTab != EventsTab.allPublic &&
              event.visibility == InstanceVisibility.public &&
              !topics.contains(event.topicId)) {
            return false;
          }

        case EventsTab.awaitingMyResponse:

          // only show events awaiting your response
          if (rsvp?.status != InstanceMemberStatus.invited ||
              event.getTimeGroup(now) == InstanceTimeGroup.past) {
            return false;
          }

        case EventsTab.imGoing:
          // only show events you at least might be going to
          if (!_goingStatuses.contains(rsvp?.status)) {
            return false;
          }

        case EventsTab.imHosting:
          // only show events you're hosting
          if (event.createdById != session?.user.id) {
            return false;
          }

        case EventsTab.allPublic:
          // only show public events
          if (event.visibility != InstanceVisibility.public) {
            return false;
          }

          // don't show canceled events
          if (event.status != InstanceStatus.live) {
            return false;
          }
      }

      // any remaining events are visible, if the API returned them
      return true;
    }).toList(),
    topics: topics
  );
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final _fabKey = GlobalKey<ExpandableFabState>();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final eventsTab = ref.watch(_eventsTabProvider);
    final eventsList = ref.watch(_filteredEventsProvider);
    final rsvpsList = ref.watch(rsvpsProvider);
    final session = ref.read(authControllerProvider);
    final friendsList = ref.watch(friendsProvider);
    final pendingFriendsList = friendsList.value?.where((friend) =>
            friend.status == FriendStatus.requested &&
            friend.requesterId != session?.user.id) ??
        [];

    final awaitingMyResponseCount =
        eventsList.valueOrNull?.awaitingMyResponseCount ?? 0;

    return AppScaffold(
      showDrawer: true,
      title: 'Explore Events',
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        key: _fabKey,
        type: ExpandableFabType.up,
        distance: 80,
        childrenAnimation: ExpandableFabAnimation.none,
        overlayStyle: ExpandableFabOverlayStyle(
          color: Colors.black.withOpacity(0.75),
          blur: 5,
        ),
        openButtonBuilder: RotateFloatingActionButtonBuilder(
          child: const Icon(Icons.add),
        ),
        closeButtonBuilder: DefaultFloatingActionButtonBuilder(
          child: const Icon(Icons.close),
        ),
        children: [
          Row(
            children: [
              const Text('Create New Event'),
              const SizedBox(width: 20),
              FloatingActionButton(
                heroTag: null,
                onPressed: () {
                  final fabState = _fabKey.currentState;
                  if (fabState != null && fabState.isOpen) {
                    fabState.toggle();
                  }

                  context.pushNamed('post-event');
                },
                child: const Icon(Icons.keyboard),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Import from Facebook'),
              const SizedBox(width: 20),
              FloatingActionButton(
                heroTag: null,
                onPressed: () async {
                  final fabState = _fabKey.currentState;
                  if (fabState != null && fabState.isOpen) {
                    fabState.toggle();
                  }

                  final url = await _promptFacebookUrl(context);
                  if (url == null) return;
                  if (!context.mounted) return;
                  context.pushNamed('post-event', queryParameters: {
                    'facebookUrl': url,
                  });
                },
                child: const Icon(Icons.facebook),
              ),
            ],
          ),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (pendingFriendsList.isNotEmpty)
          InkWell(
              onTap: () {
                context.pushNamed('friends');
              },
              child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber[900],
                  ),
                  child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          children: [
                            TextSpan(
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                text: 'You have'
                                    ' ${pendingFriendsList.length == 1 ? 'a pending friend request' : 'pending friend requests'}'
                                    ' from'
                                    ' ${pendingFriendsList.map((fr) => fr.requester!.displayName).join(', ')}\n\n'),
                            const TextSpan(
                                text:
                                    'Head to the buddy list screen to accept or reject the request.')
                          ])))),
        TabBar.secondary(
          controller: _tabController,
          onTap: (value) {
            ref.read(_eventsTabProvider.notifier).state = switch (value) {
              0 => EventsTab.invitedAndSubscribed,
              1 => EventsTab.awaitingMyResponse,
              2 => EventsTab.imGoing,
              3 => EventsTab.imHosting,
              4 => EventsTab.allPublic,
              _ => throw 'Invalid tab index',
            };
          },
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: <Widget>[
            const Tab(text: 'Invited & Subscribed'),
            Tab(
              child: Badge.count(
                count: awaitingMyResponseCount,
                isLabelVisible: awaitingMyResponseCount > 0,
                offset: const Offset(20, -5),
                child: const Text('Awaiting My Response'),
              ),
            ),
            const Tab(text: 'I\'m Going'),
            const Tab(text: 'I\'m Hosting'),
            const Tab(text: 'All Public'),
          ],
        ),
        ...eventsList.when(
            loading: () => [
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                ],
            error: (error, stackTrace) =>
                [Expanded(child: Center(child: Text('Error: $error')))],
            data: (data) {
              final now = DateTime.now();

              return [
                if (data.topics.isEmpty &&
                    eventsTab == EventsTab.invitedAndSubscribed)
                  InkWell(
                      onTap: () {
                        context.pushNamed('topics');
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'You haven\'t subscribed to any topics yet!\n\nTap here to head to the Topics screen and subscribe to some to see public events.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, fontStyle: FontStyle.italic),
                        ),
                      ))
                else if (data.events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      switch (eventsTab) {
                        EventsTab.invitedAndSubscribed =>
                          'There are no events yet that you\'ve been invited to, have been shared by friends, or are public and match your subscribed topics.\n\n'
                              'Subscribe to more topics, add some friends, or start planning your own event!',
                        EventsTab.awaitingMyResponse =>
                          'There are no events right now that you\'ve been invited and haven\'t responded to.\n\n'
                              'Check back here later!',
                        EventsTab.imGoing =>
                          'There are no events yet that you\'ve RSVP\'d to.\n\n'
                              'Check back here when you\'ve accepted some invitations!',
                        EventsTab.imHosting =>
                          'There are no events yet that you\'re hosting.\n\n'
                              'Create a new event to get started!',
                        EventsTab.allPublic =>
                          'There are no public events yet.\n\n'
                              'Check back here later!',
                      },
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontStyle: FontStyle.italic),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      return ref.read(instancesProvider.notifier).refresh();
                    },
                    child: GroupedListView(
                      elements: data.events,
                      physics: const AlwaysScrollableScrollPhysics(),
                      useStickyGroupSeparators: true,
                      // floatingHeader: true,
                      stickyHeaderBackgroundColor:
                          Theme.of(context).scaffoldBackgroundColor,
                      groupBy: (Instance instance) =>
                          instance.getTimeGroup(now),
                      groupComparator: (group1, group2) {
                        return group1.index.compareTo(group2.index);
                      },
                      groupSeparatorBuilder: (InstanceTimeGroup group) =>
                          Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                switch (group) {
                                  InstanceTimeGroup.past => 'In the past',
                                  InstanceTimeGroup.current => 'Happening now',
                                  InstanceTimeGroup.upcoming => 'Coming up',
                                },
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18),
                              )),
                      itemBuilder: (context, instance) {
                        return InstanceTile(
                            instance: instance,
                            rsvp: rsvpsList.hasValue
                                ? rsvpsList.value!
                                    .cast<InstanceMember?>()
                                    .firstWhereOrNull((rsvp) =>
                                        rsvp!.instanceId == instance.id)
                                : null,
                            onTap: () {
                              context
                                  .pushNamed('event-details', pathParameters: {
                                'id': instance.id!,
                              });
                            },
                            onEndTap:
                                session?.user.id == instance.createdById &&
                                        instance.getTimeGroup(now) ==
                                            InstanceTimeGroup.current
                                    ? _endEvent
                                    : null);
                      },
                      itemComparator: (instance1, instance2) {
                        // sort past events in reverse chronological order
                        if (instance1.startTimeMax.isBefore(now) &&
                            instance2.startTimeMax.isBefore(now)) {
                          return instance2.startTimeMax
                              .compareTo(instance1.startTimeMax);
                        }

                        // sort current/upcoming events in chronological order
                        return instance1.startTimeMax
                            .compareTo(instance2.startTimeMax);
                      },
                    ),
                  ),
                )
              ];
            }),
      ]),
    );
  }

  Future<void> _endEvent(Instance instance) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              title: const Text('End event?'),
              content: const Text(
                  'Are you sure you want to end this event? Location sharing will be stopped for all guests.'),
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

    await ref.read(instancesProvider.notifier).patch(
        instance.id!, {'end_time': DateTime.now().toUtc().toIso8601String()});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Your event has been ended and location sharing will be stopped'),
      ));
    }
  }

  Future<String?> _promptFacebookUrl(BuildContext context) {
    final urlController = TextEditingController();

    return showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
              title: const Text('Import Event from Facebook'),
              content: TextFormField(
                controller: urlController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.facebook),
                  labelText: 'Paste Facebook event URL',
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(urlController.text.trim()),
                  child: const Text('Load and edit'),
                ),
              ],
            ));
  }
}
