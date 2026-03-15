import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

class TopicsListScreenV5 extends ConsumerStatefulWidget {
  const TopicsListScreenV5({super.key});

  @override
  ConsumerState<TopicsListScreenV5> createState() => _TopicsListScreenV5State();
}

class _TopicsListScreenV5State extends ConsumerState<TopicsListScreenV5> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  final Set<String> _subscribedTopicIds = {};

  late final List<_MockCategory> _categories;
  late final List<_MockTopic> _topics;

  @override
  void initState() {
    super.initState();

    _categories = [
      _MockCategory(name: 'All', icon: Icons.apps, color: Colors.blueGrey),
      _MockCategory(
          name: 'Sports', icon: Icons.sports_basketball, color: Colors.orange),
      _MockCategory(
          name: 'Outdoors', icon: Icons.landscape, color: Colors.green),
      _MockCategory(name: 'Games', icon: Icons.casino, color: Colors.purple),
      _MockCategory(
          name: 'Food & Drink', icon: Icons.restaurant, color: Colors.red),
      _MockCategory(name: 'Arts', icon: Icons.palette, color: Colors.teal),
      _MockCategory(name: 'Social', icon: Icons.people, color: Colors.indigo),
    ];

    _topics = [
      _MockTopic(
          id: '1',
          name: 'Basketball',
          categories: ['Sports'],
          events: 8,
          icon: Icons.sports_basketball),
      _MockTopic(
          id: '2',
          name: 'Soccer',
          categories: ['Sports'],
          events: 12,
          icon: Icons.sports_soccer),
      _MockTopic(
          id: '3',
          name: 'Tennis',
          categories: ['Sports'],
          events: 5,
          icon: Icons.sports_tennis),
      _MockTopic(
          id: '4',
          name: 'Trail Running',
          categories: ['Sports', 'Outdoors'],
          events: 6,
          icon: Icons.directions_run),
      _MockTopic(
          id: '5',
          name: 'Road Running',
          categories: ['Sports'],
          events: 4,
          icon: Icons.directions_run),
      _MockTopic(
          id: '6',
          name: 'Swimming',
          categories: ['Sports'],
          events: 3,
          icon: Icons.pool),
      _MockTopic(
          id: '7',
          name: 'Hiking',
          categories: ['Outdoors'],
          events: 9,
          icon: Icons.hiking),
      _MockTopic(
          id: '8',
          name: 'Rock Climbing',
          categories: ['Sports', 'Outdoors'],
          events: 4,
          icon: Icons.terrain),
      _MockTopic(
          id: '9',
          name: 'Camping',
          categories: ['Outdoors'],
          events: 3,
          icon: Icons.cabin),
      _MockTopic(
          id: '10',
          name: 'Kayaking',
          categories: ['Sports', 'Outdoors'],
          events: 2,
          icon: Icons.kayaking),
      _MockTopic(
          id: '11',
          name: 'Board Games',
          categories: ['Games'],
          events: 7,
          icon: Icons.extension),
      _MockTopic(
          id: '12',
          name: 'Video Games',
          categories: ['Games'],
          events: 5,
          icon: Icons.videogame_asset),
      _MockTopic(
          id: '13',
          name: 'Trivia Night',
          categories: ['Games', 'Social'],
          events: 6,
          icon: Icons.quiz),
      _MockTopic(
          id: '14',
          name: 'Card Games',
          categories: ['Games'],
          events: 3,
          icon: Icons.style),
      _MockTopic(
          id: '15',
          name: 'Cooking',
          categories: ['Food & Drink'],
          events: 8,
          icon: Icons.soup_kitchen),
      _MockTopic(
          id: '16',
          name: 'Wine Tasting',
          categories: ['Food & Drink'],
          events: 4,
          icon: Icons.wine_bar),
      _MockTopic(
          id: '17',
          name: 'Coffee Meetup',
          categories: ['Food & Drink'],
          events: 5,
          icon: Icons.coffee),
      _MockTopic(
          id: '18',
          name: 'Photography',
          categories: ['Arts'],
          events: 6,
          icon: Icons.camera_alt),
      _MockTopic(
          id: '19',
          name: 'Painting',
          categories: ['Arts'],
          events: 3,
          icon: Icons.brush),
      _MockTopic(
          id: '20',
          name: 'Live Music',
          categories: ['Arts', 'Social'],
          events: 10,
          icon: Icons.music_note),
      _MockTopic(
          id: '21',
          name: 'Movie Nights',
          categories: ['Social'],
          events: 7,
          icon: Icons.movie),
      _MockTopic(
          id: '22',
          name: 'Book Club',
          categories: ['Social'],
          events: 4,
          icon: Icons.menu_book),
      _MockTopic(
          id: '23',
          name: 'Karaoke',
          categories: ['Social'],
          events: 5,
          icon: Icons.mic),
    ];

    // Pre-subscribe a few
    _subscribedTopicIds.addAll(['1', '7', '11', '18']);
  }

  List<_MockTopic> get _filteredTopics {
    var topics = _topics.toList();

    if (_selectedCategory != 'All') {
      topics = topics
          .where((t) => t.categories.contains(_selectedCategory))
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      topics = topics
          .where((t) =>
              t.name.toLowerCase().contains(query) ||
              t.categories.any((c) => c.toLowerCase().contains(query)))
          .toList();
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

    final showSubscribedOnly = context.knobs.boolean(
      label: 'Show subscribed only',
      initial: false,
      description: 'Only show topics the user has subscribed to',
    );

    final colorScheme = Theme.of(context).colorScheme;
    final filtered = showSubscribedOnly
        ? _filteredTopics
            .where((t) => _subscribedTopicIds.contains(t.id))
            .toList()
        : _filteredTopics;

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
                  'Explore categories and subscribe to topics you love',
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

          // Category bar
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category.name;

                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCategory = category.name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 76,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category.icon,
                          color:
                              isSelected ? colorScheme.primary : category.color,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Topic count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  _selectedCategory == 'All' ? 'All Topics' : _selectedCategory,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    filtered.length.toString(),
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Topic grid
          Expanded(
            child: showEmptyState || filtered.isEmpty
                ? _buildEmptyState(context)
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final topic = filtered[index];
                      final isSubscribed =
                          _subscribedTopicIds.contains(topic.id);
                      final categoryColor = _categories
                          .firstWhere((c) => c.name == topic.categories.first,
                              orElse: () => _categories.first)
                          .color;

                      return _buildTopicCard(
                        context,
                        topic,
                        isSubscribed: isSubscribed,
                        categoryColor: categoryColor,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(
    BuildContext context,
    _MockTopic topic, {
    required bool isSubscribed,
    required Color categoryColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isSubscribed ? 2 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSubscribed
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSubscribed) {
              _subscribedTopicIds.remove(topic.id);
            } else {
              _subscribedTopicIds.add(topic.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (topic.categories.length == 1)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: categoryColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(topic.icon, size: 20, color: categoryColor),
                    )
                  else
                    SizedBox(
                      width: 24.0 + (topic.categories.length - 1) * 18.0,
                      height: 32,
                      child: Stack(
                        children: [
                          for (var i = 0; i < topic.categories.length; i++)
                            Positioned(
                              left: i * 18.0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _categories
                                      .firstWhere(
                                          (c) => c.name == topic.categories[i],
                                          orElse: () => _categories.first)
                                      .color
                                      .withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  _categories
                                      .firstWhere(
                                          (c) => c.name == topic.categories[i],
                                          orElse: () => _categories.first)
                                      .icon,
                                  size: 16,
                                  color: _categories
                                      .firstWhere(
                                          (c) => c.name == topic.categories[i],
                                          orElse: () => _categories.first)
                                      .color,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (isSubscribed)
                    Icon(Icons.check_circle,
                        size: 22, color: colorScheme.primary)
                  else
                    Icon(Icons.add_circle_outline,
                        size: 22, color: colorScheme.onSurface.withAlpha(120)),
                ],
              ),
              const Spacer(),
              Text(
                topic.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${topic.events} events',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
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
              _searchQuery.isNotEmpty
                  ? 'Try a different search term or category'
                  : 'Try selecting a different category',
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
  final Color color;

  _MockCategory({
    required this.name,
    required this.icon,
    required this.color,
  });
}

class _MockTopic {
  final String id;
  final String name;
  final List<String> categories;
  final int events;
  final IconData icon;

  _MockTopic({
    required this.id,
    required this.name,
    required this.categories,
    required this.events,
    required this.icon,
  });
}
