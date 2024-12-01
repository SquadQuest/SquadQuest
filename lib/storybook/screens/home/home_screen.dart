import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/instance.dart';

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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  EventFilter selectedFilter = EventFilter.all;

  @override
  Widget build(BuildContext context) {
    final showFriendRequests = context.knobs.boolean(
      label: 'Show friend requests',
      initial: false,
      description: 'Toggle friend requests banner',
    );

    return AppScaffold(
      title: 'SquadQuest',
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Friend Requests Banner
          if (showFriendRequests)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.tertiary,
                      Theme.of(context).colorScheme.tertiaryContainer,
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
                        color: Theme.of(context).colorScheme.onTertiary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Friend Requests',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onTertiary,
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
                        foregroundColor:
                            Theme.of(context).colorScheme.onTertiary,
                      ),
                      child: const Text('View'),
                    ),
                  ],
                ),
              ),
            ),

          // Filter Chips
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: EventFilter.values.map((filter) {
                          final isSelected = selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text(filter.label),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => selectedFilter = filter);
                                }
                              },
                              avatar: isSelected
                                  ? const Icon(Icons.check, size: 18)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Text(
                        selectedFilter.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: CustomScrollView(
          slivers: [
            // Happening Now Section
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.play_circle,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Happening Now',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildEventCard(
                      context,
                      title: 'Board Game Night',
                      time: 'Started 30m ago',
                      location: 'Game Knight Lounge',
                      attendees: 8,
                      isLive: true,
                    ),
                  ],
                ),
              ),
            ),

            // Coming Up Section
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.upcoming,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Coming Up',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildEventCard(
                      context,
                      title: 'Weekend Hike',
                      time: 'Tomorrow at 9:00 AM',
                      location: 'Forest Park',
                      attendees: 5,
                    ),
                    const SizedBox(height: 16),
                    _buildEventCard(
                      context,
                      title: 'Photography Walk',
                      time: 'Saturday at 4:00 PM',
                      location: 'Waterfront Park',
                      attendees: 12,
                    ),
                  ],
                ),
              ),
            ),

            // Past Events Section
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.history,
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Past Events',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildEventCard(
                      context,
                      title: 'Movie Night',
                      time: 'Yesterday at 7:00 PM',
                      location: 'Living Room Cinema',
                      attendees: 15,
                      isPast: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
      ),
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
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          decoration:
                              isPast ? TextDecoration.lineThrough : null,
                        ),
                  ),
                  const SizedBox(height: 8),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$attendees going',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (!isPast)
                        TextButton(
                          onPressed: () {},
                          child: const Text('View Details'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
