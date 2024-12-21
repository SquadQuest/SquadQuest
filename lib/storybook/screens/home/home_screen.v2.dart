import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

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

class HomeScreenV2 extends ConsumerStatefulWidget {
  const HomeScreenV2({super.key});

  @override
  ConsumerState<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends ConsumerState<HomeScreenV2> {
  EventFilter selectedFilter = EventFilter.all;
  bool _isTransitioning = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Mock data for different filters
  final Map<EventFilter, List<_MockEventSection>> _filterContent = {
    EventFilter.all: [
      _MockEventSection(
        title: 'Happening Now',
        icon: Icons.play_circle,
        events: [
          _MockEvent(
            title: 'Board Game Night',
            time: 'Started 30m ago',
            location: 'Game Knight Lounge',
            topic: 'Board Games',
            hostName: 'Sarah Chen',
            goingCount: 5,
            maybeCount: 2,
            omwCount: 1,
            invitedCount: 4,
            isLive: true,
          ),
        ],
      ),
      _MockEventSection(
        title: 'Coming Up',
        icon: Icons.upcoming,
        events: [
          _MockEvent(
            title: 'Weekend Hike',
            time: 'Tomorrow at 9:00 AM',
            location: 'Forest Park',
            topic: 'Hiking',
            hostName: 'Mike Johnson',
            goingCount: 3,
            maybeCount: 1,
            omwCount: 0,
            invitedCount: 8,
          ),
          _MockEvent(
            title: 'Photography Walk',
            time: 'Saturday at 4:00 PM',
            location: 'Waterfront Park',
            topic: 'Photography',
            hostName: 'Lisa Wong',
            goingCount: 8,
            maybeCount: 3,
            omwCount: 0,
            invitedCount: 15,
          ),
        ],
      ),
    ],
    EventFilter.pending: [
      _MockEventSection(
        title: 'Needs Response',
        icon: Icons.schedule,
        events: [
          _MockEvent(
            title: 'Movie Marathon',
            time: 'Next Friday at 7:00 PM',
            location: 'Sarah\'s Place',
            topic: 'Movies',
            hostName: 'Sarah Chen',
            goingCount: 4,
            maybeCount: 1,
            omwCount: 1,
            invitedCount: 10,
          ),
          _MockEvent(
            title: 'Bike Ride',
            time: 'Sunday at 10:00 AM',
            location: 'Waterfront Park',
            topic: 'Cycling',
            hostName: 'David Kim',
            goingCount: 2,
            maybeCount: 1,
            omwCount: 1,
            invitedCount: 6,
          ),
        ],
      ),
    ],
    EventFilter.going: [
      _MockEventSection(
        title: 'This Week',
        icon: Icons.event,
        events: [
          _MockEvent(
            title: 'Book Club Meeting',
            time: 'Thursday at 6:00 PM',
            location: 'Powell\'s Books',
            topic: 'Book Club',
            hostName: 'Emma Davis',
            goingCount: 6,
            maybeCount: 1,
            omwCount: 1,
            invitedCount: 12,
          ),
        ],
      ),
      _MockEventSection(
        title: 'Later',
        icon: Icons.calendar_month,
        events: [
          _MockEvent(
            title: 'Art Gallery Opening',
            time: 'Next Month',
            location: 'Downtown Gallery',
            topic: 'Art',
            hostName: 'John Smith',
            goingCount: 12,
            maybeCount: 2,
            omwCount: 1,
            invitedCount: 25,
          ),
        ],
      ),
    ],
    EventFilter.hosting: [
      _MockEventSection(
        title: 'Active Events',
        icon: Icons.event_available,
        events: [
          _MockEvent(
            title: 'Weekly Game Night',
            time: 'Every Thursday',
            location: 'Community Center',
            topic: 'Board Games',
            hostName: 'Sarah Chen',
            goingCount: 7,
            maybeCount: 2,
            omwCount: 1,
            invitedCount: 15,
          ),
        ],
      ),
      _MockEventSection(
        title: 'Past Events',
        icon: Icons.history,
        events: [
          _MockEvent(
            title: 'Movie Night',
            time: 'Last Week',
            location: 'Living Room Cinema',
            topic: 'Movies',
            hostName: 'Sarah Chen',
            goingCount: 12,
            maybeCount: 2,
            omwCount: 1,
            invitedCount: 20,
            isPast: true,
          ),
        ],
      ),
    ],
    EventFilter.discover: [
      _MockEventSection(
        title: 'Recommended',
        icon: Icons.recommend,
        events: [
          _MockEvent(
            title: 'Community Picnic',
            time: 'Next Saturday',
            location: 'Laurelhurst Park',
            topic: 'Social',
            hostName: 'Community Center',
            goingCount: 20,
            maybeCount: 3,
            omwCount: 2,
            invitedCount: 50,
          ),
          _MockEvent(
            title: 'Local Music Night',
            time: 'Friday at 8:00 PM',
            location: 'The Firkin Tavern',
            topic: 'Music',
            hostName: 'The Firkin',
            goingCount: 25,
            maybeCount: 3,
            omwCount: 2,
            invitedCount: 100,
          ),
        ],
      ),
    ],
  };

  // Mock search results
  final List<_MockEvent> _allEvents = [
    _MockEvent(
      title: 'Board Game Night',
      time: 'Started 30m ago',
      location: 'Game Knight Lounge',
      topic: 'Board Games',
      hostName: 'Sarah Chen',
      goingCount: 5,
      maybeCount: 2,
      omwCount: 1,
      invitedCount: 4,
      isLive: true,
    ),
    _MockEvent(
      title: 'Weekend Hike',
      time: 'Tomorrow at 9:00 AM',
      location: 'Forest Park',
      topic: 'Hiking',
      hostName: 'Mike Johnson',
      goingCount: 3,
      maybeCount: 1,
      omwCount: 1,
      invitedCount: 8,
    ),
    _MockEvent(
      title: 'Photography Walk',
      time: 'Saturday at 4:00 PM',
      location: 'Waterfront Park',
      topic: 'Photography',
      hostName: 'Lisa Wong',
      goingCount: 8,
      maybeCount: 3,
      omwCount: 1,
      invitedCount: 15,
    ),
  ];

  List<_MockEvent> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    return _allEvents.where((event) {
      return event.title.toLowerCase().contains(query) ||
          event.location.toLowerCase().contains(query);
    }).toList();
  }

  void _changeFilter(EventFilter newFilter) async {
    if (newFilter == selectedFilter) return;

    setState(() {
      _isTransitioning = true;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    setState(() {
      selectedFilter = newFilter;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    setState(() {
      _isTransitioning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showFriendRequests = context.knobs.boolean(
      label: 'Show friend requests',
      initial: false,
      description: 'Toggle friend requests banner',
    );

    final sections = _filterContent[selectedFilter] ?? [];

    return AppScaffold(
      title: 'SquadQuest',
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = '';
                _searchController.clear();
              }
            });
          },
        ),
      ],
      body: Column(
        children: [
          // Search Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _isSearching ? 72 : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isSearching ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),
          ),

          // Search Results or Main Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isSearching && _searchQuery.isNotEmpty
                  ? _buildSearchResults()
                  : NestedScrollView(
                      key: const ValueKey('main_content'),
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                        if (showFriendRequests)
                          SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.tertiary,
                                    Theme.of(context)
                                        .colorScheme
                                        .tertiaryContainer,
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onTertiary
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person_add,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onTertiary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'New Friend Requests',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onTertiary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Sarah and Mike want to be friends',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onTertiary
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {},
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(context)
                                          .colorScheme
                                          .onTertiary,
                                    ),
                                    child: const Text('View'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _FilterHeaderDelegate(
                            child: Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 16, 16, 0),
                                    child: Row(
                                      children:
                                          EventFilter.values.map((filter) {
                                        final isSelected =
                                            selectedFilter == filter;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: FilterChip(
                                            selected: isSelected,
                                            label: Text(filter.label),
                                            onSelected: (selected) {
                                              if (selected) {
                                                _changeFilter(filter);
                                              }
                                            },
                                            avatar: isSelected
                                                ? const Icon(Icons.check,
                                                    size: 18)
                                                : null,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 16),
                                    child: Text(
                                      selectedFilter.description,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      body: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
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
                            : CustomScrollView(
                                key: ValueKey(selectedFilter),
                                slivers: [
                                  for (final section in sections)
                                    SliverPadding(
                                      padding: const EdgeInsets.all(16),
                                      sliver: SliverToBoxAdapter(
                                        child: _buildSection(
                                          context,
                                          title: section.title,
                                          icon: section.icon,
                                          events: section.events,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isSearching
          ? null
          : FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
            ),
    );
  }

  Widget _buildSearchResults() {
    final results = _searchResults;
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No events found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ],
        ),
      );
    }

    final liveEvents = results.where((event) => event.isLive).toList();
    final upcomingEvents =
        results.where((event) => !event.isLive && !event.isPast).toList();
    final pastEvents = results.where((event) => event.isPast).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (liveEvents.isNotEmpty)
          _buildSection(
            context,
            title: 'Live Now',
            icon: Icons.play_circle,
            events: liveEvents,
          ),
        if (upcomingEvents.isNotEmpty) ...[
          if (liveEvents.isNotEmpty) const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Upcoming',
            icon: Icons.upcoming,
            events: upcomingEvents,
          ),
        ],
        if (pastEvents.isNotEmpty) ...[
          if (liveEvents.isNotEmpty || upcomingEvents.isNotEmpty)
            const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Past',
            icon: Icons.history,
            events: pastEvents,
          ),
        ],
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_MockEvent> events,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...events.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildEventCard(
                context,
                title: event.title,
                time: event.time,
                location: event.location,
                attendees: event.attendees,
                isLive: event.isLive,
                isPast: event.isPast,
              ),
            )),
      ],
    );
  }

  Widget _buildEventCard(
    BuildContext context, {
    required String title,
    required String time,
    required String location,
    required int attendees,
    bool isLive = false,
    bool isPast = false,
  }) {
    final event = _MockEvent(
      title: title,
      time: time,
      location: location,
      isLive: isLive,
      isPast: isPast,
      // Set omwCount to 0 for non-live events
      omwCount: isLive ? 2 : 0,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live Now',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Topic
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                decoration:
                                    isPast ? TextDecoration.lineThrough : null,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          event.topic,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Host Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          event.hostName[0],
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hosted by ${event.hostName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Time and Location
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.place,
                        size: 16,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Attendance Stats
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildAttendanceStats(context, event),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStats(
    BuildContext context,
    _MockEvent event,
  ) {
    final hasOmw = event.isLive && event.omwCount > 0;
    final stats = [
      if (hasOmw) (Icons.directions_run, event.omwCount, 'OMW'),
      (Icons.check_circle, event.goingCount, 'Going'),
      (Icons.schedule, event.maybeCount, 'Maybe'),
      (Icons.mail_outline, event.invitedCount, 'Invited'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '|',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSecondaryContainer
                        .withOpacity(0.5),
                  ),
                ),
              ),
            Icon(
              stats[i].$1,
              size: 16,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              '${stats[i].$2} ${stats[i].$3}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _FilterHeaderDelegate({
    required this.child,
    this.height = 100,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

class _MockEventSection {
  final String title;
  final IconData icon;
  final List<_MockEvent> events;

  _MockEventSection({
    required this.title,
    required this.icon,
    required this.events,
  });
}

class _MockEvent {
  final String title;
  final String time;
  final String location;
  final String topic;
  final String hostName;
  final int goingCount;
  final int maybeCount;
  final int omwCount;
  final int invitedCount;
  final bool isLive;
  final bool isPast;

  _MockEvent({
    required this.title,
    required this.time,
    required this.location,
    this.topic = 'Board Games',
    this.hostName = 'Sarah Chen',
    this.goingCount = 5,
    this.maybeCount = 3,
    this.omwCount = 2,
    this.invitedCount = 4,
    this.isLive = false,
    this.isPast = false,
  });

  int get attendees => goingCount + maybeCount + omwCount;
}
