import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

class TopicsListScreen extends ConsumerStatefulWidget {
  const TopicsListScreen({super.key});

  @override
  ConsumerState<TopicsListScreen> createState() => _TopicsListScreenState();
}

class _TopicsListScreenState extends ConsumerState<TopicsListScreen> {
  late List<_MockTopic> subscribedTopics;
  late List<_MockTopic> suggestedTopics;
  _MockTopic? movingTopic;
  bool isSubscribing = false;

  // Grid layout constants
  static const double gridSpacing = 16.0;
  static const double cardAspectRatio = 1.5;
  static const int crossAxisCount = 2;

  @override
  void initState() {
    super.initState();
    subscribedTopics = [
      _MockTopic(
        id: '1',
        name: 'Board Games',
        events: 5,
        isSubscribed: true,
      ),
      _MockTopic(
        id: '2',
        name: 'Hiking',
        events: 3,
        isSubscribed: true,
      ),
      _MockTopic(
        id: '3',
        name: 'Photography',
        events: 2,
        isSubscribed: true,
      ),
    ];

    suggestedTopics = [
      _MockTopic(
        id: '4',
        name: 'Rock Climbing',
        events: 4,
        isSubscribed: false,
      ),
      _MockTopic(
        id: '5',
        name: 'Movie Nights',
        events: 2,
        isSubscribed: false,
      ),
      _MockTopic(
        id: '6',
        name: 'Book Club',
        events: 1,
        isSubscribed: false,
      ),
      _MockTopic(
        id: '7',
        name: 'Cooking',
        events: 3,
        isSubscribed: false,
      ),
      _MockTopic(
        id: '8',
        name: 'Cycling',
        events: 2,
        isSubscribed: false,
      ),
      _MockTopic(
        id: '9',
        name: 'Art Gallery',
        events: 1,
        isSubscribed: false,
      ),
    ];
  }

  double _calculateGridHeight(int itemCount, double availableWidth) {
    if (itemCount == 0) return 0;

    final cardWidth = (availableWidth - gridSpacing) / crossAxisCount;
    final cardHeight = cardWidth / cardAspectRatio;
    final rowCount = (itemCount / crossAxisCount).ceil();

    return rowCount * cardHeight + (rowCount - 1) * gridSpacing;
  }

  void _toggleSubscription(_MockTopic topic) async {
    setState(() {
      movingTopic = topic;
      isSubscribing = !topic.isSubscribed;
    });

    // Wait for hero animation to start
    await Future.delayed(const Duration(milliseconds: 100));

    final newTopic = _MockTopic(
      id: topic.id,
      name: topic.name,
      events: topic.events,
      isSubscribed: !topic.isSubscribed,
    );

    setState(() {
      if (!topic.isSubscribed) {
        // Remove from suggested
        suggestedTopics.remove(topic);
        // Add to subscribed
        subscribedTopics.add(newTopic);
      } else {
        // Remove from subscribed
        subscribedTopics.remove(topic);
        // Add to suggested
        suggestedTopics.add(newTopic);
      }
    });

    // Reset moving state after animation
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      movingTopic = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth =
                          constraints.maxWidth - 32; // Padding
                      final subscribedHeight = _calculateGridHeight(
                          subscribedTopics.length, availableWidth);
                      final suggestedHeight = _calculateGridHeight(
                          suggestedTopics.length, availableWidth);

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Subscribed Topics
                          Column(
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
                                      subscribedTopics.length.toString(),
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
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: subscribedHeight,
                                curve: Curves.easeInOut,
                                child: _buildTopicGrid(
                                  context,
                                  topics: subscribedTopics,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Suggested Topics
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Suggested Topics',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: suggestedHeight,
                                curve: Curves.easeInOut,
                                child: _buildTopicGrid(
                                  context,
                                  topics: suggestedTopics,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicGrid(
    BuildContext context, {
    required List<_MockTopic> topics,
  }) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: gridSpacing,
        crossAxisSpacing: gridSpacing,
        childAspectRatio: cardAspectRatio,
      ),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final topic = topics[index];
        final isMoving = movingTopic?.id == topic.id;

        return Hero(
          tag: 'topic-${topic.id}',
          flightShuttleBuilder: (
            BuildContext flightContext,
            Animation<double> animation,
            HeroFlightDirection flightDirection,
            BuildContext fromHeroContext,
            BuildContext toHeroContext,
          ) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Material(
                  color: Colors.transparent,
                  child: _buildTopicCard(
                    context,
                    topic,
                    isMoving: true,
                    opacity: isSubscribing
                        ? flightDirection == HeroFlightDirection.push
                            ? animation.value
                            : 1 - animation.value
                        : flightDirection == HeroFlightDirection.push
                            ? 1 - animation.value
                            : animation.value,
                  ),
                );
              },
            );
          },
          child: _buildTopicCard(
            context,
            topic,
            isMoving: isMoving,
            opacity: isMoving ? 0.0 : 1.0,
          ),
        );
      },
    );
  }

  Widget _buildTopicCard(
    BuildContext context,
    _MockTopic topic, {
    bool isMoving = false,
    double opacity = 1.0,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: opacity,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isMoving ? null : () => _toggleSubscription(topic),
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
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    onPressed:
                        isMoving ? null : () => _toggleSubscription(topic),
                  ),
                ),
            ],
          ),
        ),
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
}

class _MockTopic {
  final String id;
  final String name;
  final int events;
  final bool isSubscribed;

  _MockTopic({
    required this.id,
    required this.name,
    required this.events,
    required this.isSubscribed,
  });
}
