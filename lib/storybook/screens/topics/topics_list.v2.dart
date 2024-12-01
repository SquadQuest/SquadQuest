import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

class TopicsListScreenV2 extends ConsumerStatefulWidget {
  const TopicsListScreenV2({super.key});

  @override
  ConsumerState<TopicsListScreenV2> createState() => _TopicsListScreenStateV2();
}

class _TopicsListScreenStateV2 extends ConsumerState<TopicsListScreenV2> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  _MockTopic? _movingTopic;
  bool _isSubscribing = false;

  // Mock topics data
  final List<_MockTopic> _subscribedTopics = [
    _MockTopic(
      name: 'Board Games',
      description: 'Strategy, party games, and tabletop fun',
      events: 5,
      isSubscribed: true,
    ),
    _MockTopic(
      name: 'Hiking',
      description: 'Trail adventures and outdoor exploration',
      events: 3,
      isSubscribed: true,
    ),
  ];

  final List<_MockTopic> _suggestedTopics = [
    _MockTopic(
      name: 'Photography',
      description: 'Capture moments and share techniques',
      events: 2,
      isSubscribed: false,
    ),
    _MockTopic(
      name: 'Book Club',
      description: 'Read and discuss together',
      events: 1,
      isSubscribed: false,
    ),
  ];

  // Additional topics only shown in search
  final List<_MockTopic> _allTopics = [
    _MockTopic(
      name: 'Cooking',
      description: 'Share recipes and cook together',
      events: 8,
      isSubscribed: false,
    ),
    _MockTopic(
      name: 'Language Exchange',
      description: 'Practice languages with native speakers',
      events: 4,
      isSubscribed: false,
    ),
    _MockTopic(
      name: 'Movie Nights',
      description: 'Watch and discuss films together',
      events: 6,
      isSubscribed: false,
    ),
    _MockTopic(
      name: 'Tech Talks',
      description: 'Share knowledge and learn new technologies',
      events: 3,
      isSubscribed: false,
    ),
  ];

  List<_MockTopic> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    return [..._subscribedTopics, ..._suggestedTopics, ..._allTopics]
        .where((topic) {
      return topic.name.toLowerCase().contains(query) ||
          topic.description.toLowerCase().contains(query);
    }).toList();
  }

  void _toggleSubscription(_MockTopic topic) async {
    setState(() {
      _movingTopic = topic;
      _isSubscribing = !topic.isSubscribed;
    });

    // Wait for hero animation to start
    await Future.delayed(const Duration(milliseconds: 100));

    setState(() {
      if (topic.isSubscribed) {
        // Remove from subscribed
        _subscribedTopics.remove(topic);
        // Add to suggested
        _suggestedTopics.add(topic.copyWith(isSubscribed: false));
      } else {
        // Remove from suggested or search results
        _suggestedTopics.remove(topic);
        _allTopics.remove(topic);
        // Add to subscribed
        _subscribedTopics.add(topic.copyWith(isSubscribed: true));
      }
    });

    // Reset moving state after animation
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _movingTopic = null;
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
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search topics...',
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
              ],
            ),
          ),

          // Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults()
                  : showEmptyState
                      ? _buildEmptyState(context)
                      : CustomScrollView(
                          slivers: [
                            // My Topics Section
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _subscribedTopics.length.toString(),
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
                                    if (_subscribedTopics.isEmpty)
                                      _buildEmptySection(
                                        context,
                                        icon: Icons.interests_outlined,
                                        title: 'No Topics Yet',
                                        description:
                                            'Subscribe to topics you\'re interested in to discover relevant events',
                                      )
                                    else
                                      _buildTopicGrid(
                                        context,
                                        topics: _subscribedTopics,
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Suggested Topics Section
                            SliverPadding(
                              padding: const EdgeInsets.all(16),
                              sliver: SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Suggested Topics',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    if (_suggestedTopics.isEmpty)
                                      _buildEmptySection(
                                        context,
                                        icon: Icons.recommend,
                                        title: 'No Suggestions Yet',
                                        description:
                                            'Check back later for personalized topic suggestions',
                                      )
                                    else
                                      _buildTopicGrid(
                                        context,
                                        topics: _suggestedTopics,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
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
              'No Topics Found',
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

    final subscribedResults =
        results.where((topic) => topic.isSubscribed).toList();
    final unsubscribedResults =
        results.where((topic) => !topic.isSubscribed).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (subscribedResults.isNotEmpty) ...[
          Text(
            'My Topics',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildTopicGrid(context, topics: subscribedResults),
        ],
        if (unsubscribedResults.isNotEmpty) ...[
          if (subscribedResults.isNotEmpty) const SizedBox(height: 32),
          Text(
            'Available Topics',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildTopicGrid(context, topics: unsubscribedResults),
        ],
      ],
    );
  }

  Widget _buildEmptySection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
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
        final isMoving = _movingTopic?.name == topic.name;

        return Hero(
          tag: 'topic-${topic.name}',
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
                    opacity: _isSubscribing
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
                      topic.description,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
}

class _MockTopic {
  final String name;
  final String description;
  final int events;
  final bool isSubscribed;

  _MockTopic({
    required this.name,
    required this.description,
    required this.events,
    required this.isSubscribed,
  });

  _MockTopic copyWith({
    String? name,
    String? description,
    int? events,
    bool? isSubscribed,
  }) {
    return _MockTopic(
      name: name ?? this.name,
      description: description ?? this.description,
      events: events ?? this.events,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }
}
