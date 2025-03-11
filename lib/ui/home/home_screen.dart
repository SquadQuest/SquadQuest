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
import 'widgets/home_topics_prompt_banner.dart';
import 'widgets/home_filter_bar.dart';
import 'widgets/home_event_list.dart';
import 'widgets/home_search_results.dart';

final _filteredEventsWithStatsProvider =
    FutureProvider<List<Instance>>((ref) async {
  final events = await ref.watch(instancesProvider.future);
  final topics = await ref.watch(topicSubscriptionsProvider.future);
  final rsvpsList = ref.watch(rsvpsProvider).valueOrNull ?? [];
  final eventsTab = ref.watch(_selectedFilterProvider);
  final session = ref.read(authControllerProvider);
  final now = DateTime.now();

  return events.where((event) {
    final rsvp =
        rsvpsList.firstWhereOrNull((rsvp) => rsvp.instanceId == event.id);

    final isCreator = event.createdById == session?.user.id;

    // never show draft events unless you created it
    if (event.status == InstanceStatus.draft && !isCreator) {
      return false;
    }

    // Don't filter out canceled events if you created them or have an RSVP
    final isInvolved = isCreator || rsvp != null;

    // For public events you're not involved with, only show live ones
    if (!isInvolved && event.status != InstanceStatus.live) {
      return false;
    }

    return switch (eventsTab) {
      EventFilter.feed =>
        // events you're invited to
        isInvolved ||
            // public events you're subscribed to
            (event.visibility != InstanceVisibility.public ||
                topics.contains(event.topicId)),
      EventFilter.invited => rsvp?.status == InstanceMemberStatus.invited &&
          event.getTimeGroup(now) != InstanceTimeGroup.past,
      EventFilter.going => [
          InstanceMemberStatus.maybe,
          InstanceMemberStatus.yes,
          InstanceMemberStatus.omw,
        ].contains(rsvp?.status),
      EventFilter.hosting => isCreator,
      EventFilter.public => event.visibility == InstanceVisibility.public,
    };
  }).toList();
});

final _searchResultsProvider = Provider<List<Instance>>((ref) {
  final query = ref.watch(_searchQueryProvider).toLowerCase();
  if (query.isEmpty) return [];

  final eventsAsync = ref.watch(_filteredEventsWithStatsProvider);
  return eventsAsync.when(
    loading: () => [],
    error: (_, __) => [],
    data: (events) => events.where((event) {
      return event.title.toLowerCase().contains(query) ||
          event.locationDescription.toLowerCase().contains(query) ||
          event.notes?.toLowerCase().contains(query) == true ||
          event.topic?.name.toLowerCase().contains(query) == true;
    }).toList(),
  );
});

final _rsvpStatusesProvider =
    Provider<Map<InstanceID, InstanceMemberStatus>>((ref) {
  final rsvpsList = ref.watch(rsvpsProvider).valueOrNull ?? [];
  final statuses = <InstanceID, InstanceMemberStatus>{};

  for (final rsvp in rsvpsList) {
    if (rsvp.instanceId != null) {
      statuses[rsvp.instanceId!] = rsvp.status;
    }
  }

  return statuses;
});

enum EventFilter {
  feed('Feed', 'Events you\'re invited to or match your interests'),
  invited('Invited', 'Events awaiting your response'),
  going('Going', 'Events you\'re attending'),
  hosting('Hosting', 'Events you\'re organizing'),
  public('Public', 'All public events');

  final String label;
  final String description;
  const EventFilter(this.label, this.description);
}

final _selectedFilterProvider =
    StateProvider<EventFilter>((ref) => EventFilter.feed);
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
    final eventsAsync = ref.watch(_filteredEventsWithStatsProvider);
    final rsvpStatuses = ref.watch(_rsvpStatusesProvider);
    final topics = ref.watch(topicSubscriptionsProvider);

    final friendsList = ref.watch(friendsProvider);
    final pendingFriendRequests = friendsList.value
            ?.where((friend) =>
                friend.status == FriendStatus.requested &&
                friend.requesterId != session?.user.id)
            .toList() ??
        [];

    return AppScaffold(
      title: 'SquadQuest',
      showDrawer: true,
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
                      rsvps: rsvpStatuses,
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
                                : eventsAsync.when(
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (error, stack) => Center(
                                      child: Text('Error: $error'),
                                    ),
                                    data: (events) {
                                      if (events.isEmpty &&
                                          topics.hasValue &&
                                          topics.value!.isEmpty &&
                                          selectedFilter == EventFilter.feed) {
                                        return HomeTopicsPromptBanner(
                                          onTap: _navigateToTopics,
                                        );
                                      }

                                      return RefreshIndicator(
                                        onRefresh: () async {
                                          return ref
                                              .read(instancesProvider.notifier)
                                              .refresh();
                                        },
                                        child: HomeEventList(
                                          events: events,
                                          onEventTap: _navigateToEventDetails,
                                          onEndEvent: _endEvent,
                                          rsvps: rsvpStatuses,
                                        ),
                                      );
                                    },
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
