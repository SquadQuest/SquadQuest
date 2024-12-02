import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

enum TopicState {
  none,
  following,
  subscribed,
}

class TopicsListScreenV1 extends ConsumerStatefulWidget {
  const TopicsListScreenV1({super.key});

  @override
  ConsumerState<TopicsListScreenV1> createState() => _TopicsListScreenV1State();
}

class _TopicsListScreenV1State extends ConsumerState<TopicsListScreenV1> {
  late List<_MockTopic> subscribedTopics;
  late List<_MockTopic> suggestedTopics;
  _MockTopic? movingTopic;
  bool isSubscribing = false;
  bool showHelpBanner = true;

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
        state: TopicState.subscribed,
      ),
      _MockTopic(
        id: '2',
        name: 'Hiking',
        events: 3,
        state: TopicState.subscribed,
      ),
      _MockTopic(
        id: '3',
        name: 'Photography',
        events: 2,
        state: TopicState.following,
      ),
    ];

    suggestedTopics = [
      _MockTopic(
        id: '4',
        name: 'Rock Climbing',
        events: 4,
      ),
      _MockTopic(
        id: '5',
        name: 'Movie Nights',
        events: 2,
      ),
      _MockTopic(
        id: '6',
        name: 'Book Club',
        events: 1,
      ),
      _MockTopic(
        id: '7',
        name: 'Cooking',
        events: 3,
      ),
      _MockTopic(
        id: '8',
        name: 'Cycling',
        events: 2,
      ),
      _MockTopic(
        id: '9',
        name: 'Art Gallery',
        events: 1,
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

  void _toggleSubscription(_MockTopic topic, bool useThreeStateMode) async {
    final nextState = useThreeStateMode
        ? switch (topic.state) {
            TopicState.none => TopicState.following,
            TopicState.following => TopicState.subscribed,
            TopicState.subscribed => TopicState.none,
          }
        : topic.isSubscribed
            ? TopicState.none
            : TopicState.subscribed;

    setState(() {
      movingTopic = topic;
      isSubscribing = nextState != TopicState.none;
    });

    // Wait for hero animation to start
    await Future.delayed(const Duration(milliseconds: 100));

    final newTopic = topic.copyWith(state: nextState);

    setState(() {
      if (nextState == TopicState.none) {
        // Remove from subscribed
        subscribedTopics.remove(topic);
        // Add to suggested
        suggestedTopics.add(newTopic);
      } else {
        // Remove from suggested if it's there
        if (suggestedTopics.contains(topic)) {
          final index = suggestedTopics.indexOf(topic);
          suggestedTopics.removeAt(index);
        }
        // Update in subscribed if it's there, otherwise add it
        final index = subscribedTopics.indexWhere((t) => t.id == topic.id);
        if (index != -1) {
          subscribedTopics[index] = newTopic;
        } else {
          subscribedTopics.add(newTopic);
        }
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

    final useThreeStateMode = context.knobs.boolean(
      label: 'Use three-state mode',
      initial: false,
      description:
          'Toggle between two-state (subscribed/none) and three-state (subscribed/following/none) modes',
    );

    return AppScaffold(
      title: 'Topics',
      body: Column(
        children: [
          // Help Banner
          if (useThreeStateMode && showHelpBanner)
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'You can now follow topics to see updates without notifications, or subscribe to get notified of new events. Tap a topic to cycle through states.',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => showHelpBanner = false),
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),

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
                                  useThreeStateMode: useThreeStateMode,
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
                                  useThreeStateMode: useThreeStateMode,
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
    required bool useThreeStateMode,
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
                    useThreeStateMode: useThreeStateMode,
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
            useThreeStateMode: useThreeStateMode,
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
    required bool useThreeStateMode,
    bool isMoving = false,
    double opacity = 1.0,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: opacity,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isMoving
              ? null
              : () => _toggleSubscription(topic, useThreeStateMode),
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
                    if (topic.state != TopicState.none)
                      Chip(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(
                          useThreeStateMode
                              ? (topic.state == TopicState.subscribed
                                  ? 'Subscribed'
                                  : 'Following')
                              : 'Subscribed',
                        ),
                        avatar: Icon(
                          useThreeStateMode
                              ? (topic.state == TopicState.subscribed
                                  ? Icons.notifications_active
                                  : Icons.remove_red_eye)
                              : Icons.check,
                          size: 16,
                        ),
                        backgroundColor: useThreeStateMode
                            ? (topic.state == TopicState.subscribed
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer)
                            : Theme.of(context).colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color: useThreeStateMode
                              ? (topic.state == TopicState.subscribed
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer)
                              : Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                        ),
                      ),
                  ],
                ),
              ),

              // Toggle Button
              if (topic.state == TopicState.none)
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: isMoving
                        ? null
                        : () => _toggleSubscription(topic, useThreeStateMode),
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
  final TopicState state;

  _MockTopic({
    required this.id,
    required this.name,
    required this.events,
    this.state = TopicState.none,
  });

  bool get isSubscribed => state == TopicState.subscribed;
  bool get isFollowing => state == TopicState.following;

  _MockTopic copyWith({TopicState? state}) {
    return _MockTopic(
      id: id,
      name: name,
      events: events,
      state: state ?? this.state,
    );
  }
}
