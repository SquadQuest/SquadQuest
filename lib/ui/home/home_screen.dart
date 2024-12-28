import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/topic_subscriptions.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/friend.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/home_friend_requests_banner.dart';
import 'widgets/home_filter_bar.dart';
import 'widgets/home_event_list.dart';
import 'widgets/home_search_results.dart';

typedef EventStats = ({int going, int maybe, int omw, int invited});
typedef EventsWithStats = ({
  List<Instance> events,
  Map<InstanceID, EventStats> stats
});

final _filteredEventsWithStatsProvider =
    FutureProvider<EventsWithStats>((ref) async {
  final events = await ref.watch(instancesProvider.future);
  final topics = await ref.watch(topicSubscriptionsProvider.future);
  final rsvpsList = ref.watch(rsvpsProvider);
  final eventsTab = ref.watch(_selectedFilterProvider);
  final session = ref.read(authControllerProvider);
  final now = DateTime.now();
  final stats = await ref.watch(_eventStatsProvider.future);

  final filteredEvents = events.where((event) {
    final rsvp = rsvpsList.value
        ?.firstWhereOrNull((rsvp) => rsvp.instanceId == event.id);

    // never show draft events unless you created it
    if (event.status == InstanceStatus.draft &&
        event.createdById != session?.user.id) {
      return false;
    }

    switch (eventsTab) {
      case EventFilter.all:
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
        if (event.visibility == InstanceVisibility.public &&
            !topics.contains(event.topicId)) {
          return false;
        }

      case EventFilter.pending:
        // only show events awaiting your response
        if (rsvp?.status != InstanceMemberStatus.invited ||
            event.getTimeGroup(now) == InstanceTimeGroup.past) {
          return false;
        }

      case EventFilter.going:
        // only show events you're going to
        if (![
          InstanceMemberStatus.maybe,
          InstanceMemberStatus.yes,
          InstanceMemberStatus.omw,
        ].contains(rsvp?.status)) {
          return false;
        }

      case EventFilter.hosting:
        // only show events you're hosting
        if (event.createdById != session?.user.id) {
          return false;
        }

      case EventFilter.discover:
        // only show public events
        if (event.visibility != InstanceVisibility.public) {
          return false;
        }

        // don't show canceled events
        if (event.status != InstanceStatus.live) {
          return false;
        }
    }

    return true;
  }).toList();

  return (events: filteredEvents, stats: stats);
});

final _eventStatsProvider =
    FutureProvider<Map<InstanceID, EventStats>>((ref) async {
  final rsvpsList = await ref.watch(rsvpsPerEventProvider('*').future);
  final stats = <InstanceID, EventStats>{};

  for (final rsvp in rsvpsList) {
    if (rsvp.instanceId == null) continue;

    final current =
        stats[rsvp.instanceId] ?? (going: 0, maybe: 0, omw: 0, invited: 0);
    final updated = switch (rsvp.status) {
      InstanceMemberStatus.invited => (
          going: current.going,
          maybe: current.maybe,
          omw: current.omw,
          invited: current.invited + 1,
        ),
      InstanceMemberStatus.maybe => (
          going: current.going,
          maybe: current.maybe + 1,
          omw: current.omw,
          invited: current.invited,
        ),
      InstanceMemberStatus.yes => (
          going: current.going + 1,
          maybe: current.maybe,
          omw: current.omw,
          invited: current.invited,
        ),
      InstanceMemberStatus.omw => (
          going: current.going,
          maybe: current.maybe,
          omw: current.omw + 1,
          invited: current.invited,
        ),
      _ => current,
    };
    stats[rsvp.instanceId!] = updated;
  }

  return stats;
});

final _searchResultsProvider = Provider<List<Instance>>((ref) {
  final query = ref.watch(_searchQueryProvider).toLowerCase();
  if (query.isEmpty) return [];

  final eventsData = ref.watch(_filteredEventsWithStatsProvider).valueOrNull;
  final events = eventsData?.events ?? [];
  return events.where((event) {
    return event.title.toLowerCase().contains(query) ||
        event.locationDescription.toLowerCase().contains(query) ||
        event.notes?.toLowerCase().contains(query) == true;
  }).toList();
});

enum EventFilter {
  all('All', 'Events you\'re invited to or match your interests'),
  pending('Pending', 'Events awaiting your response'),
  going('Going', 'Events you\'re attending'),
  hosting('Hosting', 'Events you\'re organizing'),
  discover('Discover', 'Public events you might like');

  final String label;
  final String description;
  const EventFilter(this.label, this.description);
}

final _selectedFilterProvider =
    StateProvider<EventFilter>((ref) => EventFilter.all);
final _isSearchingProvider = StateProvider<bool>((ref) => false);
final _searchQueryProvider = StateProvider<String>((ref) => '');

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isTransitioning = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeFilter(EventFilter newFilter) async {
    if (newFilter == ref.read(_selectedFilterProvider)) return;

    setState(() => _isTransitioning = true);
    await Future.delayed(const Duration(milliseconds: 150));

    ref.read(_selectedFilterProvider.notifier).state = newFilter;

    await Future.delayed(const Duration(milliseconds: 150));
    setState(() => _isTransitioning = false);
  }

  void _toggleSearch() {
    final isSearching = ref.read(_isSearchingProvider);
    ref.read(_isSearchingProvider.notifier).state = !isSearching;
    if (isSearching) {
      ref.read(_searchQueryProvider.notifier).state = '';
    }
  }

  void _updateSearchQuery(String query) {
    ref.read(_searchQueryProvider.notifier).state = query;
  }

  void _navigateToEventDetails(Instance event) {
    context.pushNamed('event-details', pathParameters: {'id': event.id!});
  }

  void _navigateToFriends() {
    context.pushNamed('friends');
  }

  void _navigateToTopics() {
    context.pushNamed('topics');
  }

  void _navigateToCreateEvent() {
    context.pushNamed('post-event');
  }

  Future<void> _endEvent(Instance instance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('End event?'),
        content: const Text(
          'Are you sure you want to end this event? Location sharing will be stopped for all guests.',
        ),
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
      ),
    );

    if (confirmed != true) return;

    await ref.read(instancesProvider.notifier).patch(
      instance.id!,
      {'end_time': DateTime.now().toUtc().toIso8601String()},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Your event has been ended and location sharing will be stopped'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final selectedFilter = ref.watch(_selectedFilterProvider);
    final isSearching = ref.watch(_isSearchingProvider);
    final searchQuery = ref.watch(_searchQueryProvider);

    final friendsList = ref.watch(friendsProvider);
    final pendingFriendRequests = friendsList.value
            ?.where((friend) =>
                friend.status == FriendStatus.requested &&
                friend.requesterId != session?.user.id)
            .toList() ??
        [];

    final eventsData = ref.watch(_filteredEventsWithStatsProvider).valueOrNull;

    return AppScaffold(
      title: 'SquadQuest',
      actions: [
        IconButton(
          icon: Icon(isSearching ? Icons.close : Icons.search),
          onPressed: _toggleSearch,
        ),
      ],
      body: Column(
        children: [
          HomeSearchBar(
            isVisible: isSearching,
            controller: _searchController,
            onChanged: _updateSearchQuery,
          ),
          HomeFriendRequestsBanner(
            pendingRequests: pendingFriendRequests,
            onTap: _navigateToFriends,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isSearching && searchQuery.isNotEmpty
                  ? HomeSearchResults(
                      query: searchQuery,
                      events: ref.watch(_searchResultsProvider),
                      onEventTap: _navigateToEventDetails,
                      onEndEvent: _endEvent,
                      eventStats: eventsData?.stats,
                    )
                  : Column(
                      children: [
                        HomeFilterBar(
                          filters: EventFilter.values
                              .map((f) =>
                                  (label: f.label, description: f.description))
                              .toList(),
                          selectedIndex:
                              EventFilter.values.indexOf(selectedFilter),
                          onFilterSelected: (index) =>
                              _changeFilter(EventFilter.values[index]),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: animation.drive(
                                    Tween(
                                      begin: const Offset(0.0, 0.1),
                                      end: Offset.zero,
                                    ).chain(CurveTween(curve: Curves.easeOut)),
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: _isTransitioning
                                ? const SizedBox.shrink()
                                : HomeEventList(
                                    events: eventsData?.events ?? [],
                                    onEventTap: _navigateToEventDetails,
                                    onEndEvent: _endEvent,
                                    eventStats: eventsData?.stats,
                                  ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: isSearching
          ? null
          : FloatingActionButton.extended(
              onPressed: _navigateToCreateEvent,
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
            ),
    );
  }
}
