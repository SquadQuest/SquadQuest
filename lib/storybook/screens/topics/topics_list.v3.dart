import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

class TopicsListScreenV3 extends ConsumerStatefulWidget {
  const TopicsListScreenV3({super.key});

  @override
  ConsumerState<TopicsListScreenV3> createState() => _TopicsListScreenV3State();
}

class _TopicsListScreenV3State extends ConsumerState<TopicsListScreenV3> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final Set<String> _subscribedTopicIds = {};
  final Set<String> _expandedCategories = {'Sports', 'Games'};

  late final List<_MockCategory> _categories;

  @override
  void initState() {
    super.initState();

    _categories = [
      _MockCategory(name: 'Sports', icon: Icons.sports_basketball, topics: [
        _MockTopic(id: '1', name: 'Basketball', events: 8),
        _MockTopic(id: '2', name: 'Soccer', events: 12),
        _MockTopic(id: '3', name: 'Tennis', events: 5),
        _MockTopic(id: '4', name: 'Trail Running', events: 6),
        _MockTopic(id: '5', name: 'Road Running', events: 4),
        _MockTopic(id: '6', name: 'Swimming', events: 3),
      ]),
      _MockCategory(name: 'Outdoors', icon: Icons.landscape, topics: [
        _MockTopic(id: '7', name: 'Hiking', events: 9),
        _MockTopic(id: '8', name: 'Rock Climbing', events: 4),
        _MockTopic(id: '9', name: 'Camping', events: 3),
        _MockTopic(id: '10', name: 'Kayaking', events: 2),
      ]),
      _MockCategory(name: 'Games', icon: Icons.casino, topics: [
        _MockTopic(id: '11', name: 'Board Games', events: 7),
        _MockTopic(id: '12', name: 'Video Games', events: 5),
        _MockTopic(id: '13', name: 'Trivia Night', events: 6),
        _MockTopic(id: '14', name: 'Card Games', events: 3),
      ]),
      _MockCategory(name: 'Food & Drink', icon: Icons.restaurant, topics: [
        _MockTopic(id: '15', name: 'Cooking', events: 8),
        _MockTopic(id: '16', name: 'Wine Tasting', events: 4),
        _MockTopic(id: '17', name: 'Coffee Meetup', events: 5),
      ]),
      _MockCategory(name: 'Arts', icon: Icons.palette, topics: [
        _MockTopic(id: '18', name: 'Photography', events: 6),
        _MockTopic(id: '19', name: 'Painting', events: 3),
        _MockTopic(id: '20', name: 'Live Music', events: 10),
      ]),
      _MockCategory(name: 'Social', icon: Icons.people, topics: [
        _MockTopic(id: '21', name: 'Movie Nights', events: 7),
        _MockTopic(id: '22', name: 'Book Club', events: 4),
        _MockTopic(id: '23', name: 'Karaoke', events: 5),
      ]),
    ];

    // Pre-subscribe a few
    _subscribedTopicIds.addAll(['1', '7', '11', '18']);
  }

  List<_MockCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;

    final query = _searchQuery.toLowerCase();
    return _categories
        .map((category) {
          final matchingTopics = category.topics
              .where((t) => t.name.toLowerCase().contains(query))
              .toList();
          if (matchingTopics.isEmpty) return null;
          return _MockCategory(
            name: category.name,
            icon: category.icon,
            topics: matchingTopics,
          );
        })
        .whereType<_MockCategory>()
        .toList();
  }

  void _toggleTopic(String topicId) {
    setState(() {
      if (_subscribedTopicIds.contains(topicId)) {
        _subscribedTopicIds.remove(topicId);
      } else {
        _subscribedTopicIds.add(topicId);
      }
    });
  }

  void _subscribeAll(List<_MockTopic> topics) {
    setState(() {
      for (final topic in topics) {
        _subscribedTopicIds.add(topic.id);
      }
    });
  }

  void _unsubscribeAll(List<_MockTopic> topics) {
    setState(() {
      for (final topic in topics) {
        _subscribedTopicIds.remove(topic.id);
      }
    });
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

    final expandAll = context.knobs.boolean(
      label: 'Expand all categories',
      initial: false,
      description: 'Expand all category sections',
    );

    final colorScheme = Theme.of(context).colorScheme;
    final filteredCategories = _filteredCategories;

    if (expandAll) {
      for (final cat in _categories) {
        _expandedCategories.add(cat.name);
      }
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
                  'Browse Topics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Expand categories to discover and subscribe to topics',
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
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      if (value.isNotEmpty) {
                        // Auto-expand all when searching
                        for (final cat in _categories) {
                          _expandedCategories.add(cat.name);
                        }
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // Subscription summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
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

          // Category tree
          Expanded(
            child: showEmptyState || filteredCategories.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = filteredCategories[index];
                      final subscribedCount = category.topics
                          .where((t) => _subscribedTopicIds.contains(t.id))
                          .length;
                      final allSubscribed =
                          subscribedCount == category.topics.length;
                      final isExpanded =
                          _expandedCategories.contains(category.name);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            key: PageStorageKey(category.name),
                            initiallyExpanded: isExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                if (expanded) {
                                  _expandedCategories.add(category.name);
                                } else {
                                  _expandedCategories.remove(category.name);
                                }
                              });
                            },
                            leading:
                                Icon(category.icon, color: colorScheme.primary),
                            title: Row(
                              children: [
                                Text(
                                  category.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                if (subscribedCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$subscribedCount/${category.topics.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    if (allSubscribed) {
                                      _unsubscribeAll(category.topics);
                                    } else {
                                      _subscribeAll(category.topics);
                                    }
                                  },
                                  child: Text(
                                    allSubscribed ? 'Unsub All' : 'Sub All',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                ),
                              ],
                            ),
                            children: category.topics.map((topic) {
                              final isSubscribed =
                                  _subscribedTopicIds.contains(topic.id);
                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                title: Text(topic.name),
                                subtitle: Text('${topic.events} events'),
                                trailing: IconButton(
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: isSubscribed
                                        ? Icon(
                                            Icons.check_circle,
                                            key: const ValueKey('sub'),
                                            color: colorScheme.primary,
                                          )
                                        : Icon(
                                            Icons.add_circle_outline,
                                            key: const ValueKey('unsub'),
                                            color: colorScheme.onSurface
                                                .withAlpha(120),
                                          ),
                                  ),
                                  onPressed: () => _toggleTopic(topic.id),
                                ),
                                onTap: () => _toggleTopic(topic.id),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
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
              'Try a different search term',
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

class _MockCategory {
  final String name;
  final IconData icon;
  final List<_MockTopic> topics;

  _MockCategory({
    required this.name,
    required this.icon,
    required this.topics,
  });
}

class _MockTopic {
  final String id;
  final String name;
  final int events;

  _MockTopic({
    required this.id,
    required this.name,
    required this.events,
  });
}
