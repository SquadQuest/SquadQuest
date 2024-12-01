import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

class TopicsListScreen extends ConsumerWidget {
  const TopicsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showEmptyState = context.knobs.boolean(
      label: 'Show empty state',
      initial: false,
      description: 'Toggle between empty and populated states',
    );

    return AppScaffold(
      title: 'Topics',
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find Your Interests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Subscribe to topics you\'re interested in to discover relevant events',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                ),
                const SizedBox(height: 16),
                SearchBar(
                  hintText: 'Search topics...',
                  leading: const Icon(Icons.search),
                  padding: const MaterialStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
            ),
          ),

          // Topics List
          Expanded(
            child: showEmptyState
                ? _buildEmptyState(context)
                : CustomScrollView(
                    slivers: [
                      // Subscribed Topics
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'My Topics',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '3',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildTopicGrid(
                                context,
                                topics: [
                                  _MockTopic(
                                    name: 'Board Games',
                                    events: 5,
                                    isSubscribed: true,
                                  ),
                                  _MockTopic(
                                    name: 'Hiking',
                                    events: 3,
                                    isSubscribed: true,
                                  ),
                                  _MockTopic(
                                    name: 'Photography',
                                    events: 2,
                                    isSubscribed: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Suggested Topics
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Suggested Topics',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              _buildTopicGrid(
                                context,
                                topics: [
                                  _MockTopic(
                                    name: 'Rock Climbing',
                                    events: 4,
                                    isSubscribed: false,
                                  ),
                                  _MockTopic(
                                    name: 'Movie Nights',
                                    events: 2,
                                    isSubscribed: false,
                                  ),
                                  _MockTopic(
                                    name: 'Book Club',
                                    events: 1,
                                    isSubscribed: false,
                                  ),
                                  _MockTopic(
                                    name: 'Cooking',
                                    events: 3,
                                    isSubscribed: false,
                                  ),
                                  _MockTopic(
                                    name: 'Cycling',
                                    events: 2,
                                    isSubscribed: false,
                                  ),
                                  _MockTopic(
                                    name: 'Art Gallery',
                                    events: 1,
                                    isSubscribed: false,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.interests_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Topics Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Try adjusting your search or check back later for new topics',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicGrid(
    BuildContext context, {
    required List<_MockTopic> topics,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final topic = topics[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {},
            child: Stack(
              children: [
                // Topic Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${topic.events} events',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      if (topic.isSubscribed)
                        Chip(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: const Text('Subscribed'),
                          avatar: const Icon(Icons.check, size: 16),
                        ),
                    ],
                  ),
                ),

                // Subscribe Button
                if (!topic.isSubscribed)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {},
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MockTopic {
  final String name;
  final int events;
  final bool isSubscribed;

  _MockTopic({
    required this.name,
    required this.events,
    required this.isSubscribed,
  });
}
