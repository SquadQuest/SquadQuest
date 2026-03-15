import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

class TopicsListScreenV4 extends ConsumerStatefulWidget {
  const TopicsListScreenV4({super.key});

  @override
  ConsumerState<TopicsListScreenV4> createState() => _TopicsListScreenV4State();
}

class _TopicsListScreenV4State extends ConsumerState<TopicsListScreenV4> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _selectedMetaTag = 'All';
  final Set<String> _subscribedTopicIds = {};

  static const _metaTags = [
    'All',
    'Active',
    'Fitness',
    'Social',
    'Creative',
    'Outdoors',
  ];

  late final List<_MockTopic> _topics;

  @override
  void initState() {
    super.initState();

    _topics = [
      _MockTopic(
          id: '1',
          name: 'Basketball',
          metaTags: ['Active', 'Fitness'],
          events: 8),
      _MockTopic(
          id: '2', name: 'Soccer', metaTags: ['Active', 'Fitness'], events: 12),
      _MockTopic(
          id: '3', name: 'Tennis', metaTags: ['Active', 'Fitness'], events: 5),
      _MockTopic(
          id: '4',
          name: 'Trail Running',
          metaTags: ['Active', 'Fitness', 'Outdoors'],
          events: 6),
      _MockTopic(
          id: '5',
          name: 'Road Running',
          metaTags: ['Active', 'Fitness'],
          events: 4),
      _MockTopic(
          id: '6',
          name: 'Swimming',
          metaTags: ['Active', 'Fitness'],
          events: 3),
      _MockTopic(
          id: '7', name: 'Hiking', metaTags: ['Active', 'Outdoors'], events: 9),
      _MockTopic(
          id: '8',
          name: 'Rock Climbing',
          metaTags: ['Active', 'Outdoors'],
          events: 4),
      _MockTopic(
          id: '9',
          name: 'Camping',
          metaTags: ['Outdoors', 'Social'],
          events: 3),
      _MockTopic(
          id: '10',
          name: 'Kayaking',
          metaTags: ['Active', 'Outdoors'],
          events: 2),
      _MockTopic(
          id: '11', name: 'Board Games', metaTags: ['Social'], events: 7),
      _MockTopic(
          id: '12', name: 'Video Games', metaTags: ['Social'], events: 5),
      _MockTopic(
          id: '13', name: 'Trivia Night', metaTags: ['Social'], events: 6),
      _MockTopic(id: '14', name: 'Card Games', metaTags: ['Social'], events: 3),
      _MockTopic(
          id: '15',
          name: 'Cooking',
          metaTags: ['Social', 'Creative'],
          events: 8),
      _MockTopic(
          id: '16', name: 'Wine Tasting', metaTags: ['Social'], events: 4),
      _MockTopic(
          id: '17', name: 'Coffee Meetup', metaTags: ['Social'], events: 5),
      _MockTopic(
          id: '18',
          name: 'Photography',
          metaTags: ['Creative', 'Outdoors'],
          events: 6),
      _MockTopic(id: '19', name: 'Painting', metaTags: ['Creative'], events: 3),
      _MockTopic(
          id: '20',
          name: 'Live Music',
          metaTags: ['Social', 'Creative'],
          events: 10),
      _MockTopic(
          id: '21', name: 'Movie Nights', metaTags: ['Social'], events: 7),
      _MockTopic(
          id: '22',
          name: 'Book Club',
          metaTags: ['Social', 'Creative'],
          events: 4),
      _MockTopic(
          id: '23', name: 'Karaoke', metaTags: ['Social', 'Active'], events: 5),
    ];

    // Pre-subscribe a few
    _subscribedTopicIds.addAll(['1', '7', '11', '18']);
  }

  List<_MockTopic> get _filteredTopics {
    var topics = _topics.toList();

    if (_selectedMetaTag != 'All') {
      topics =
          topics.where((t) => t.metaTags.contains(_selectedMetaTag)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      topics =
          topics.where((t) => t.name.toLowerCase().contains(query)).toList();
    }

    return topics;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showEmptyState = context.knobs.boolean(
      label: 'Show empty state',
      initial: false,
      description: 'Toggle between empty and populated states',
    );

    final showSubscribedFirst = context.knobs.boolean(
      label: 'Show subscribed first',
      initial: true,
      description: 'Group subscribed topics at the top',
    );

    final colorScheme = Theme.of(context).colorScheme;
    var filtered = _filteredTopics;

    if (showSubscribedFirst) {
      final subscribed =
          filtered.where((t) => _subscribedTopicIds.contains(t.id)).toList();
      final unsubscribed =
          filtered.where((t) => !_subscribedTopicIds.contains(t.id)).toList();
      filtered = [...subscribed, ...unsubscribed];
    }

    return AppScaffold(
      title: 'Topics',
      body: Column(
        children: [
          // Header with search
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Topics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap chips to subscribe to topics you\'re interested in',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search topics...',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ],
            ),
          ),

          // Meta-tag filter row
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _metaTags.length,
              itemBuilder: (context, index) {
                final tag = _metaTags[index];
                final isSelected = _selectedMetaTag == tag;

                return ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedMetaTag = tag),
                );
              },
            ),
          ),

          // Subscription count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} topics',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface.withAlpha(180),
                      ),
                ),
                const Spacer(),
                Text(
                  '${_subscribedTopicIds.length} subscribed',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Chip cloud
          Expanded(
            child: showEmptyState || filtered.isEmpty
                ? _buildEmptyState(context)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showSubscribedFirst &&
                            filtered.any(
                                (t) => _subscribedTopicIds.contains(t.id))) ...[
                          Text(
                            'My Topics',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: filtered
                                .where(
                                    (t) => _subscribedTopicIds.contains(t.id))
                                .map((topic) =>
                                    _buildTopicChip(context, topic, true))
                                .toList(),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Available Topics',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: filtered
                                .where(
                                    (t) => !_subscribedTopicIds.contains(t.id))
                                .map((topic) =>
                                    _buildTopicChip(context, topic, false))
                                .toList(),
                          ),
                        ] else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: filtered
                                .map((topic) => _buildTopicChip(context, topic,
                                    _subscribedTopicIds.contains(topic.id)))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicChip(
    BuildContext context,
    _MockTopic topic,
    bool isSubscribed,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(topic.name),
          const SizedBox(width: 4),
          Text(
            '${topic.events}',
            style: TextStyle(
              fontSize: 11,
              color: isSubscribed
                  ? colorScheme.onPrimaryContainer.withAlpha(180)
                  : colorScheme.onSurface.withAlpha(120),
            ),
          ),
        ],
      ),
      selected: isSubscribed,
      onSelected: (_) {
        setState(() {
          if (isSubscribed) {
            _subscribedTopicIds.remove(topic.id);
          } else {
            _subscribedTopicIds.add(topic.id);
          }
        });
      },
      showCheckmark: isSubscribed,
      avatar: isSubscribed ? null : const Icon(Icons.add, size: 16),
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
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'No Topics Found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term or filter',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
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
  final List<String> metaTags;
  final int events;

  _MockTopic({
    required this.id,
    required this.name,
    required this.metaTags,
    required this.events,
  });
}
