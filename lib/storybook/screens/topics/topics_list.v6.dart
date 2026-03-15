import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

class TopicsListScreenV6 extends ConsumerStatefulWidget {
  const TopicsListScreenV6({super.key});

  @override
  ConsumerState<TopicsListScreenV6> createState() => _TopicsListScreenV6State();
}

class _TopicsListScreenV6State extends ConsumerState<TopicsListScreenV6> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final Set<String> _subscribedTopicIds = {};

  // Active facet selections
  String? _selectedActivityType;
  String? _selectedSetting;
  String? _selectedGroupSize;

  static const _activityTypes = [
    'Physical',
    'Creative',
    'Intellectual',
    'Social',
  ];

  static const _settings = [
    'Indoor',
    'Outdoor',
    'Either',
  ];

  static const _groupSizes = [
    'Small (2-5)',
    'Medium (6-15)',
    'Large (15+)',
  ];

  late final List<_MockTopic> _topics;

  @override
  void initState() {
    super.initState();

    _topics = [
      _MockTopic(
          id: '1',
          name: 'Basketball',
          activityType: 'Physical',
          setting: 'Either',
          groupSize: 'Medium (6-15)',
          events: 8,
          icon: Icons.sports_basketball),
      _MockTopic(
          id: '2',
          name: 'Soccer',
          activityType: 'Physical',
          setting: 'Outdoor',
          groupSize: 'Large (15+)',
          events: 12,
          icon: Icons.sports_soccer),
      _MockTopic(
          id: '3',
          name: 'Tennis',
          activityType: 'Physical',
          setting: 'Either',
          groupSize: 'Small (2-5)',
          events: 5,
          icon: Icons.sports_tennis),
      _MockTopic(
          id: '4',
          name: 'Trail Running',
          activityType: 'Physical',
          setting: 'Outdoor',
          groupSize: 'Small (2-5)',
          events: 6,
          icon: Icons.directions_run),
      _MockTopic(
          id: '5',
          name: 'Road Running',
          activityType: 'Physical',
          setting: 'Outdoor',
          groupSize: 'Small (2-5)',
          events: 4,
          icon: Icons.directions_run),
      _MockTopic(
          id: '6',
          name: 'Swimming',
          activityType: 'Physical',
          setting: 'Either',
          groupSize: 'Small (2-5)',
          events: 3,
          icon: Icons.pool),
      _MockTopic(
          id: '7',
          name: 'Hiking',
          activityType: 'Physical',
          setting: 'Outdoor',
          groupSize: 'Medium (6-15)',
          events: 9,
          icon: Icons.hiking),
      _MockTopic(
          id: '8',
          name: 'Rock Climbing',
          activityType: 'Physical',
          setting: 'Either',
          groupSize: 'Small (2-5)',
          events: 4,
          icon: Icons.terrain),
      _MockTopic(
          id: '9',
          name: 'Camping',
          activityType: 'Social',
          setting: 'Outdoor',
          groupSize: 'Medium (6-15)',
          events: 3,
          icon: Icons.cabin),
      _MockTopic(
          id: '10',
          name: 'Kayaking',
          activityType: 'Physical',
          setting: 'Outdoor',
          groupSize: 'Small (2-5)',
          events: 2,
          icon: Icons.kayaking),
      _MockTopic(
          id: '11',
          name: 'Board Games',
          activityType: 'Intellectual',
          setting: 'Indoor',
          groupSize: 'Small (2-5)',
          events: 7,
          icon: Icons.extension),
      _MockTopic(
          id: '12',
          name: 'Video Games',
          activityType: 'Social',
          setting: 'Indoor',
          groupSize: 'Small (2-5)',
          events: 5,
          icon: Icons.videogame_asset),
      _MockTopic(
          id: '13',
          name: 'Trivia Night',
          activityType: 'Intellectual',
          setting: 'Indoor',
          groupSize: 'Medium (6-15)',
          events: 6,
          icon: Icons.quiz),
      _MockTopic(
          id: '14',
          name: 'Card Games',
          activityType: 'Intellectual',
          setting: 'Indoor',
          groupSize: 'Small (2-5)',
          events: 3,
          icon: Icons.style),
      _MockTopic(
          id: '15',
          name: 'Cooking',
          activityType: 'Creative',
          setting: 'Indoor',
          groupSize: 'Small (2-5)',
          events: 8,
          icon: Icons.soup_kitchen),
      _MockTopic(
          id: '16',
          name: 'Wine Tasting',
          activityType: 'Social',
          setting: 'Indoor',
          groupSize: 'Medium (6-15)',
          events: 4,
          icon: Icons.wine_bar),
      _MockTopic(
          id: '17',
          name: 'Coffee Meetup',
          activityType: 'Social',
          setting: 'Indoor',
          groupSize: 'Small (2-5)',
          events: 5,
          icon: Icons.coffee),
      _MockTopic(
          id: '18',
          name: 'Photography',
          activityType: 'Creative',
          setting: 'Either',
          groupSize: 'Small (2-5)',
          events: 6,
          icon: Icons.camera_alt),
      _MockTopic(
          id: '19',
          name: 'Painting',
          activityType: 'Creative',
          setting: 'Indoor',
          groupSize: 'Small (2-5)',
          events: 3,
          icon: Icons.brush),
      _MockTopic(
          id: '20',
          name: 'Live Music',
          activityType: 'Social',
          setting: 'Either',
          groupSize: 'Large (15+)',
          events: 10,
          icon: Icons.music_note),
      _MockTopic(
          id: '21',
          name: 'Movie Nights',
          activityType: 'Social',
          setting: 'Indoor',
          groupSize: 'Medium (6-15)',
          events: 7,
          icon: Icons.movie),
      _MockTopic(
          id: '22',
          name: 'Book Club',
          activityType: 'Intellectual',
          setting: 'Indoor',
          groupSize: 'Small (2-5)',
          events: 4,
          icon: Icons.menu_book),
      _MockTopic(
          id: '23',
          name: 'Karaoke',
          activityType: 'Social',
          setting: 'Indoor',
          groupSize: 'Medium (6-15)',
          events: 5,
          icon: Icons.mic),
    ];

    // Pre-subscribe a few
    _subscribedTopicIds.addAll(['1', '7', '11', '18']);
  }

  List<_MockTopic> get _filteredTopics {
    var topics = _topics.toList();

    if (_selectedActivityType != null) {
      topics =
          topics.where((t) => t.activityType == _selectedActivityType).toList();
    }
    if (_selectedSetting != null) {
      topics = topics.where((t) => t.setting == _selectedSetting).toList();
    }
    if (_selectedGroupSize != null) {
      topics = topics.where((t) => t.groupSize == _selectedGroupSize).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      topics =
          topics.where((t) => t.name.toLowerCase().contains(query)).toList();
    }

    return topics;
  }

  bool get _hasActiveFilters =>
      _selectedActivityType != null ||
      _selectedSetting != null ||
      _selectedGroupSize != null;

  void _clearFilters() {
    setState(() {
      _selectedActivityType = null;
      _selectedSetting = null;
      _selectedGroupSize = null;
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

    final compactFilters = context.knobs.boolean(
      label: 'Compact filters',
      initial: false,
      description: 'Use a more compact filter layout',
    );

    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredTopics;

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
                  'Discover Topics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Use filters to find exactly what you\'re looking for',
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

          // Facet filters
          Container(
            padding: EdgeInsets.all(compactFilters ? 8 : 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Activity Type
                _buildFacetRow(
                  context,
                  label: 'Activity',
                  options: _activityTypes,
                  selected: _selectedActivityType,
                  compact: compactFilters,
                  onSelected: (value) =>
                      setState(() => _selectedActivityType = value),
                ),
                SizedBox(height: compactFilters ? 6 : 10),

                // Setting
                _buildFacetRow(
                  context,
                  label: 'Setting',
                  options: _settings,
                  selected: _selectedSetting,
                  compact: compactFilters,
                  onSelected: (value) =>
                      setState(() => _selectedSetting = value),
                ),
                SizedBox(height: compactFilters ? 6 : 10),

                // Group Size
                _buildFacetRow(
                  context,
                  label: 'Group Size',
                  options: _groupSizes,
                  selected: _selectedGroupSize,
                  compact: compactFilters,
                  onSelected: (value) =>
                      setState(() => _selectedGroupSize = value),
                ),

                if (_hasActiveFilters) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${filtered.length} results',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear filters'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Results list
          Expanded(
            child: showEmptyState || filtered.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final topic = filtered[index];
                      final isSubscribed =
                          _subscribedTopicIds.contains(topic.id);

                      return _buildTopicTile(
                        context,
                        topic,
                        isSubscribed: isSubscribed,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacetRow(
    BuildContext context, {
    required String label,
    required List<String> options,
    required String? selected,
    required bool compact,
    required ValueChanged<String?> onSelected,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: compact ? 60 : 76,
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((option) {
                final isSelected = selected == option;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      option,
                      style: TextStyle(fontSize: compact ? 11 : 12),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      onSelected(isSelected ? null : option);
                    },
                    visualDensity: compact
                        ? VisualDensity.compact
                        : VisualDensity.standard,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicTile(
    BuildContext context,
    _MockTopic topic, {
    required bool isSubscribed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSubscribed
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          topic.icon,
          color: isSubscribed
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface.withAlpha(180),
        ),
      ),
      title: Text(
        topic.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          _buildBadge(context, topic.activityType),
          const SizedBox(width: 4),
          _buildBadge(context, topic.setting),
          const SizedBox(width: 4),
          _buildBadge(context, topic.groupSize.split(' ').first),
          const Spacer(),
          Text(
            '${topic.events} events',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withAlpha(120),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isSubscribed
              ? Icon(Icons.check_circle,
                  key: const ValueKey('sub'), color: colorScheme.primary)
              : Icon(Icons.add_circle_outline,
                  key: const ValueKey('unsub'),
                  color: colorScheme.onSurface.withAlpha(120)),
        ),
        onPressed: () {
          setState(() {
            if (isSubscribed) {
              _subscribedTopicIds.remove(topic.id);
            } else {
              _subscribedTopicIds.add(topic.id);
            }
          });
        },
      ),
      onTap: () {
        setState(() {
          if (isSubscribed) {
            _subscribedTopicIds.remove(topic.id);
          } else {
            _subscribedTopicIds.add(topic.id);
          }
        });
      },
    );
  }

  Widget _buildBadge(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: colorScheme.onSurface.withAlpha(160),
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
              Icons.filter_list_off,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'No Matching Topics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _hasActiveFilters
                  ? 'Try adjusting your filters or search term'
                  : 'Try a different search term',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear all filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MockTopic {
  final String id;
  final String name;
  final String activityType;
  final String setting;
  final String groupSize;
  final int events;
  final IconData icon;

  _MockTopic({
    required this.id,
    required this.name,
    required this.activityType,
    required this.setting,
    required this.groupSize,
    required this.events,
    required this.icon,
  });
}
