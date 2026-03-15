import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/topics.dart';

// Mock data models
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
  final String slug;
  final String displayName;
  final String? verb;
  final List<String> categories;
  final int events;
  final IconData icon;

  _MockTopic({
    required this.id,
    required this.slug,
    required this.displayName,
    this.verb,
    required this.categories,
    required this.events,
    required this.icon,
  });

  String get fullDisplayName =>
      verb != null ? '$verb $displayName' : displayName;
}

// Semantic similarity map: query substring → [(topicId, similarity)]
const _semanticMap = <String, List<(String, double)>>{
  'jog': [('5', 0.87), ('4', 0.82)],
  'jogging': [('5', 0.92), ('4', 0.88)],
  'hike': [('7', 0.90), ('4', 0.68)],
  'climb': [('8', 0.88), ('7', 0.62)],
  'bike': [('10', 0.85)],
  'exercise': [('4', 0.75), ('5', 0.72), ('6', 0.70), ('10', 0.68)],
  'outdoor': [('7', 0.80), ('4', 0.78), ('8', 0.75), ('9', 0.73), ('10', 0.70)],
  'games': [('11', 0.90), ('12', 0.85), ('14', 0.82), ('13', 0.75)],
  'food': [('15', 0.82), ('16', 0.70), ('17', 0.68)],
  'fitness': [('4', 0.80), ('5', 0.78), ('6', 0.75)],
  'music': [('20', 0.90), ('23', 0.72)],
  'art': [('18', 0.80), ('19', 0.85)],
};

// Related topics map (neighborhoods): topicId → [related topicIds]
const _relatedMap = <String, List<String>>{
  '1': ['2', '3', '6'], // Basketball → Soccer, Tennis, Swimming (Sports)
  '2': ['1', '3'], // Soccer → Basketball, Tennis
  '3': ['1', '2'], // Tennis → Basketball, Soccer
  '4': ['5', '7', '8'], // Trail Running → Road Running, Hiking, Rock Climbing
  '5': ['4', '6'], // Road Running → Trail Running, Swimming
  '6': ['5', '10'], // Swimming → Road Running, Kayaking
  '7': ['8', '9', '4'], // Hiking → Rock Climbing, Camping, Trail Running
  '8': ['7', '4'], // Rock Climbing → Hiking, Trail Running
  '9': ['7', '10'], // Camping → Hiking, Kayaking
  '10': ['9', '7', '6'], // Kayaking → Camping, Hiking, Swimming
  '11': ['12', '14', '13'], // Board Games → Video Games, Card Games, Trivia
  '12': ['11', '14'], // Video Games → Board Games, Card Games
  '13': ['11', '23', '22'], // Trivia Night → Board Games, Karaoke, Book Club
  '14': ['11', '12'], // Card Games → Board Games, Video Games
  '15': ['16', '17'], // Cooking → Wine Tasting, Coffee Meetup
  '16': ['15', '17'], // Wine Tasting → Cooking, Coffee Meetup
  '17': ['15', '16'], // Coffee Meetup → Cooking, Wine Tasting
  '18': ['19'], // Photography → Painting
  '19': ['18', '20'], // Painting → Photography, Live Music
  '20': ['23', '21'], // Live Music → Karaoke, Movie Nights
  '21': ['22', '20'], // Movie Nights → Book Club, Live Music
  '22': ['21', '13'], // Book Club → Movie Nights, Trivia Night
  '23': ['20', '13'], // Karaoke → Live Music, Trivia Night
};

class TopicsListScreenV7 extends ConsumerStatefulWidget {
  const TopicsListScreenV7({super.key});

  @override
  ConsumerState<TopicsListScreenV7> createState() => _TopicsListScreenV7State();
}

class _TopicsListScreenV7State extends ConsumerState<TopicsListScreenV7> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  final Set<String> _subscribedTopicIds = {'1', '7', '11', '18'};

  // Search state
  List<TopicSuggestion> _trigramResults = [];
  List<TopicSuggestion> _semanticResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _trigramDebounce;
  Timer? _semanticDebounce;

  // Neighborhoods
  String? _expandedTopicId;
  List<_MockTopic> _relatedTopics = [];
  bool _loadingRelated = false;

  // Knob state
  bool _simulateSemanticDelay = false;

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
          slug: 'basketball',
          displayName: 'Basketball',
          verb: 'Play',
          categories: ['Sports'],
          events: 8,
          icon: Icons.sports_basketball),
      _MockTopic(
          id: '2',
          slug: 'soccer',
          displayName: 'Soccer',
          verb: 'Play',
          categories: ['Sports'],
          events: 12,
          icon: Icons.sports_soccer),
      _MockTopic(
          id: '3',
          slug: 'tennis',
          displayName: 'Tennis',
          verb: 'Play',
          categories: ['Sports'],
          events: 5,
          icon: Icons.sports_tennis),
      _MockTopic(
          id: '4',
          slug: 'trail-running',
          displayName: 'Trail Running',
          verb: 'Go',
          categories: ['Sports', 'Outdoors'],
          events: 6,
          icon: Icons.directions_run),
      _MockTopic(
          id: '5',
          slug: 'road-running',
          displayName: 'Road Running',
          verb: 'Go',
          categories: ['Sports'],
          events: 4,
          icon: Icons.directions_run),
      _MockTopic(
          id: '6',
          slug: 'swimming',
          displayName: 'Swimming',
          verb: 'Go',
          categories: ['Sports'],
          events: 3,
          icon: Icons.pool),
      _MockTopic(
          id: '7',
          slug: 'hiking',
          displayName: 'Hiking',
          verb: 'Go',
          categories: ['Outdoors'],
          events: 9,
          icon: Icons.hiking),
      _MockTopic(
          id: '8',
          slug: 'rock-climbing',
          displayName: 'Rock Climbing',
          categories: ['Sports', 'Outdoors'],
          events: 4,
          icon: Icons.terrain),
      _MockTopic(
          id: '9',
          slug: 'camping',
          displayName: 'Camping',
          verb: 'Go',
          categories: ['Outdoors'],
          events: 3,
          icon: Icons.cabin),
      _MockTopic(
          id: '10',
          slug: 'kayaking',
          displayName: 'Kayaking',
          verb: 'Go',
          categories: ['Sports', 'Outdoors'],
          events: 2,
          icon: Icons.kayaking),
      _MockTopic(
          id: '11',
          slug: 'board-games',
          displayName: 'Board Games',
          categories: ['Games'],
          events: 7,
          icon: Icons.extension),
      _MockTopic(
          id: '12',
          slug: 'video-games',
          displayName: 'Video Games',
          categories: ['Games'],
          events: 5,
          icon: Icons.videogame_asset),
      _MockTopic(
          id: '13',
          slug: 'trivia-night',
          displayName: 'Trivia Night',
          categories: ['Games', 'Social'],
          events: 6,
          icon: Icons.quiz),
      _MockTopic(
          id: '14',
          slug: 'card-games',
          displayName: 'Card Games',
          verb: 'Play',
          categories: ['Games'],
          events: 3,
          icon: Icons.style),
      _MockTopic(
          id: '15',
          slug: 'cooking',
          displayName: 'Cooking',
          verb: 'Learn',
          categories: ['Food & Drink'],
          events: 8,
          icon: Icons.soup_kitchen),
      _MockTopic(
          id: '16',
          slug: 'wine-tasting',
          displayName: 'Wine Tasting',
          categories: ['Food & Drink'],
          events: 4,
          icon: Icons.wine_bar),
      _MockTopic(
          id: '17',
          slug: 'coffee-meetup',
          displayName: 'Coffee Meetup',
          categories: ['Food & Drink'],
          events: 5,
          icon: Icons.coffee),
      _MockTopic(
          id: '18',
          slug: 'photography',
          displayName: 'Photography',
          categories: ['Arts'],
          events: 6,
          icon: Icons.camera_alt),
      _MockTopic(
          id: '19',
          slug: 'painting',
          displayName: 'Painting',
          verb: 'Make',
          categories: ['Arts'],
          events: 3,
          icon: Icons.brush),
      _MockTopic(
          id: '20',
          slug: 'live-music',
          displayName: 'Live Music',
          verb: 'Watch',
          categories: ['Arts', 'Social'],
          events: 10,
          icon: Icons.music_note),
      _MockTopic(
          id: '21',
          slug: 'movie-nights',
          displayName: 'Movie Nights',
          verb: 'Watch',
          categories: ['Social'],
          events: 7,
          icon: Icons.movie),
      _MockTopic(
          id: '22',
          slug: 'book-club',
          displayName: 'Book Club',
          categories: ['Social'],
          events: 4,
          icon: Icons.menu_book),
      _MockTopic(
          id: '23',
          slug: 'karaoke',
          displayName: 'Karaoke',
          categories: ['Social'],
          events: 5,
          icon: Icons.mic),
    ];
  }

  @override
  void dispose() {
    _trigramDebounce?.cancel();
    _semanticDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isSearchActive => _searchQuery.isNotEmpty;

  _MockTopic? _topicById(String id) {
    return _topics.where((t) => t.id == id).firstOrNull;
  }

  List<_MockTopic> get _filteredTopics {
    var topics = _topics.toList();
    if (_selectedCategory != 'All') {
      topics = topics
          .where((t) => t.categories.contains(_selectedCategory))
          .toList();
    }
    return topics;
  }

  // --- Search logic ---

  void _onSearchChanged(String value) {
    final query = value.trim();
    setState(() => _searchQuery = query);

    if (query.isEmpty) {
      setState(() {
        _trigramResults = [];
        _semanticResults = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    _trigramDebounce?.cancel();
    _trigramDebounce = Timer(const Duration(milliseconds: 200), () {
      _runTrigramSearch(query);
    });

    _semanticDebounce?.cancel();
    if (query.length >= 3) {
      _semanticDebounce = Timer(const Duration(milliseconds: 500), () {
        _runSemanticSearch(query);
      });
    }
  }

  void _runTrigramSearch(String query) {
    final lowerQuery = query.toLowerCase();

    // Filter by selected category too
    var searchPool = _topics.toList();
    if (_selectedCategory != 'All') {
      searchPool = searchPool
          .where((t) => t.categories.contains(_selectedCategory))
          .toList();
    }

    final results = searchPool
        .where((t) =>
            t.displayName.toLowerCase().contains(lowerQuery) ||
            t.slug.contains(lowerQuery))
        .map((t) => TopicSuggestion(
              id: t.id,
              name: t.slug,
              displayName: t.displayName,
              similarity:
                  _trigramSimilarity(t.displayName.toLowerCase(), lowerQuery),
            ))
        .toList()
      ..sort((a, b) => b.similarity.compareTo(a.similarity));

    if (mounted && _searchQuery == query) {
      setState(() {
        _trigramResults = results;
        _hasSearched = true;
      });
    }
  }

  double _trigramSimilarity(String text, String query) {
    if (text == query) return 1.0;
    if (text.startsWith(query)) return 0.9;
    if (text.contains(query)) return 0.7;
    return 0.5;
  }

  Future<void> _runSemanticSearch(String query) async {
    if (_trigramResults.length >= 3) return;

    setState(() => _isSearching = true);

    if (_simulateSemanticDelay) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted || _searchQuery != query) return;

    final lowerQuery = query.toLowerCase();
    final List<TopicSuggestion> results = [];

    for (final entry in _semanticMap.entries) {
      if (lowerQuery.contains(entry.key) || entry.key.contains(lowerQuery)) {
        for (final (topicId, similarity) in entry.value) {
          // Filter by category if one is selected
          if (_selectedCategory != 'All') {
            final topic = _topicById(topicId);
            if (topic == null ||
                !topic.categories.contains(_selectedCategory)) {
              continue;
            }
          }
          final topic = _topicById(topicId);
          if (topic != null && !results.any((r) => r.id == topicId)) {
            results.add(TopicSuggestion(
              id: topicId,
              name: topic.slug,
              displayName: topic.displayName,
              similarity: similarity,
            ));
          }
        }
      }
    }

    results.sort((a, b) => b.similarity.compareTo(a.similarity));

    setState(() {
      _semanticResults = results;
      _isSearching = false;
    });
  }

  // --- Neighborhoods ---

  Future<void> _loadRelatedTopics(String topicId) async {
    if (_expandedTopicId == topicId) {
      setState(() {
        _expandedTopicId = null;
        _relatedTopics = [];
      });
      return;
    }

    setState(() {
      _expandedTopicId = topicId;
      _loadingRelated = true;
      _relatedTopics = [];
    });

    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted || _expandedTopicId != topicId) return;

    final relatedIds = _relatedMap[topicId] ?? [];
    final results = relatedIds
        .map((id) => _topicById(id))
        .where((t) => t != null)
        .cast<_MockTopic>()
        .toList();

    setState(() {
      _relatedTopics = results;
      _loadingRelated = false;
    });
  }

  // --- Actions ---

  void _toggleSubscription(String topicId) {
    setState(() {
      if (_subscribedTopicIds.contains(topicId)) {
        _subscribedTopicIds.remove(topicId);
      } else {
        _subscribedTopicIds.add(topicId);
      }
    });
  }

  void _showCreateDialog() {
    final displayName = _searchController.text.trim();
    if (displayName.isEmpty) return;

    final highMatches = <TopicSuggestion>[
      ..._trigramResults.where((s) => s.similarity > 0.7),
      ..._semanticResults.where((s) => s.similarity > 0.7),
    ];

    String? selectedVerb;
    const verbOptions = ['Play', 'Watch', 'Learn', 'Make', 'Go'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
              highMatches.isNotEmpty ? 'Similar topic exists' : 'Create Topic'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (highMatches.isNotEmpty) ...[
                Text(
                    'This looks similar to existing ${highMatches.length == 1 ? 'topic' : 'topics'}:'),
                const SizedBox(height: 8),
                ...highMatches.map((m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${m.label}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    )),
                const SizedBox(height: 12),
                const Text('Create a new topic anyway?'),
                const SizedBox(height: 16),
              ],
              Text('Verb', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('None'),
                    selected: selectedVerb == null,
                    onSelected: (_) =>
                        setDialogState(() => selectedVerb = null),
                  ),
                  ...verbOptions.map((verb) => ChoiceChip(
                        label: Text(verb),
                        selected: selectedVerb == verb,
                        onSelected: (_) =>
                            setDialogState(() => selectedVerb = verb),
                      )),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
                _createTopic(displayName, verb: selectedVerb);
              },
              child: Text(highMatches.isNotEmpty ? 'Create anyway' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _createTopic(String displayName, {String? verb}) {
    final slug = displayName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s\-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');

    final newId = 'new-${DateTime.now().millisecondsSinceEpoch}';
    final newTopic = _MockTopic(
      id: newId,
      slug: slug,
      displayName: displayName,
      verb: verb,
      categories: [_selectedCategory == 'All' ? 'Social' : _selectedCategory],
      events: 0,
      icon: Icons.tag,
    );

    setState(() {
      _topics.add(newTopic);
      _subscribedTopicIds.add(newId);
      _searchController.clear();
      _searchQuery = '';
      _trigramResults = [];
      _semanticResults = [];
      _hasSearched = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created and subscribed to "$displayName"')),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final showSubscribedOnly = context.knobs.boolean(
      label: 'Show subscribed only',
      initial: false,
      description: 'Filter to subscribed topics in grid mode',
    );

    _simulateSemanticDelay = context.knobs.boolean(
      label: 'Simulate semantic delay',
      initial: false,
      description: '500ms delay on semantic search results',
    );

    final colorScheme = Theme.of(context).colorScheme;

    var gridTopics = _filteredTopics;
    if (showSubscribedOnly) {
      gridTopics =
          gridTopics.where((t) => _subscribedTopicIds.contains(t.id)).toList();
    }

    // Deduplicate search results
    final allSuggestionIds = <String>{};
    final trigramOnly = <TopicSuggestion>[];
    final semanticOnly = <TopicSuggestion>[];

    for (final result in _trigramResults) {
      if (allSuggestionIds.add(result.id)) {
        trigramOnly.add(result);
      }
    }
    for (final result in _semanticResults) {
      if (allSuggestionIds.add(result.id)) {
        semanticOnly.add(result);
      }
    }

    final showCreateButton =
        _hasSearched && _searchController.text.trim().isNotEmpty;

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
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ],
            ),
          ),

          // Category bar — always visible but visually secondary during search
          AnimatedOpacity(
            opacity: _isSearchActive ? 0.6 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category.name;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = category.name);
                      // Re-run search if active
                      if (_isSearchActive) {
                        _trigramDebounce?.cancel();
                        _semanticDebounce?.cancel();
                        _runTrigramSearch(_searchQuery);
                        if (_searchQuery.length >= 3) {
                          _runSemanticSearch(_searchQuery);
                        }
                      }
                    },
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
                            color: isSelected
                                ? colorScheme.primary
                                : category.color,
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
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
          ),

          // Main content area
          Expanded(
            child: _isSearchActive
                ? _buildSearchResults(
                    trigramOnly, semanticOnly, showCreateButton)
                : _buildCategoryGrid(gridTopics),
          ),
        ],
      ),
    );
  }

  // --- Grid mode (no search) ---

  Widget _buildCategoryGrid(List<_MockTopic> topics) {
    final colorScheme = Theme.of(context).colorScheme;

    if (topics.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Topic count header
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  topics.length.toString(),
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSubscribed = _subscribedTopicIds.contains(topic.id);
              final isExpanded = _expandedTopicId == topic.id;
              final categoryColor = _categories
                  .firstWhere((c) => c.name == topic.categories.first,
                      orElse: () => _categories.first)
                  .color;

              return _buildTopicCard(
                topic,
                isSubscribed: isSubscribed,
                isExpanded: isExpanded,
                categoryColor: categoryColor,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopicCard(
    _MockTopic topic, {
    required bool isSubscribed,
    required bool isExpanded,
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
        onTap: () => _toggleSubscription(topic.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Category icons
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
                                    color: colorScheme.surface,
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
                  // Explore icon
                  InkWell(
                    onTap: () => _showNeighborhoodSheet(topic.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(
                      Icons.explore,
                      size: 20,
                      color: colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (isSubscribed)
                    Icon(Icons.check_circle,
                        size: 22, color: colorScheme.primary)
                  else
                    Icon(Icons.add_circle_outline,
                        size: 22, color: colorScheme.onSurface.withAlpha(120)),
                ],
              ),
              const Spacer(),
              if (topic.verb != null)
                Text(
                  topic.verb!.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withAlpha(120),
                        letterSpacing: 1.2,
                      ),
                ),
              Text(
                topic.displayName,
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

  void _showNeighborhoodSheet(String topicId) {
    final topic = _topicById(topicId);
    if (topic == null) return;

    final relatedIds = _relatedMap[topicId] ?? [];
    final relatedTopics = relatedIds
        .map((id) => _topicById(id))
        .where((t) => t != null)
        .cast<_MockTopic>()
        .toList();

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.explore,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Related to ${topic.displayName}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (relatedTopics.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No related topics found',
                          style: TextStyle(fontStyle: FontStyle.italic)),
                    )
                  else
                    ...relatedTopics.map((related) {
                      final isSubscribed =
                          _subscribedTopicIds.contains(related.id);
                      final relatedCategoryColor = _categories
                          .firstWhere((c) => c.name == related.categories.first,
                              orElse: () => _categories.first)
                          .color;

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: relatedCategoryColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(related.icon,
                              size: 20, color: relatedCategoryColor),
                        ),
                        title: Text(related.fullDisplayName),
                        subtitle: Text('${related.events} events'),
                        trailing: Switch(
                          value: isSubscribed,
                          onChanged: (_) {
                            _toggleSubscription(related.id);
                            setSheetState(() {});
                          },
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Search mode ---

  Widget _buildSearchResults(List<TopicSuggestion> trigramOnly,
      List<TopicSuggestion> semanticOnly, bool showCreateButton) {
    return ListView(
      children: [
        // Trigram results
        if (_hasSearched && trigramOnly.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Search Results',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ...trigramOnly.map((s) => _buildSearchResultTile(s)),
        ],

        // Semantic results
        if (semanticOnly.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Similar Topics',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          ...semanticOnly.map((s) => _buildSearchResultTile(s)),
        ],

        // No results
        if (_hasSearched &&
            trigramOnly.isEmpty &&
            semanticOnly.isEmpty &&
            !_isSearching)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No topics found. Try different search terms.',
              textAlign: TextAlign.center,
            ),
          ),

        // Create button
        if (showCreateButton)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add, size: 18),
              label: Text('Create "${_searchController.text.trim()}"'),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResultTile(TopicSuggestion suggestion) {
    final isSubscribed = _subscribedTopicIds.contains(suggestion.id);
    final isExpanded = _expandedTopicId == suggestion.id;
    final topic = _topicById(suggestion.id);
    final eventCount = topic?.events ?? 0;

    // Similarity indicator
    final TextStyle? subtitleStyle;
    final String? subtitleText;
    if (suggestion.similarity > 0.85) {
      subtitleStyle = TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontSize: 12,
      );
      subtitleText = 'Very similar match';
    } else if (suggestion.similarity > 0.7) {
      subtitleStyle = TextStyle(
        color: Theme.of(context).colorScheme.tertiary,
        fontSize: 12,
      );
      subtitleText = 'Similar match';
    } else {
      subtitleStyle = null;
      subtitleText = null;
    }

    final subtitle = subtitleText != null
        ? subtitleText + (eventCount > 0 ? ' · $eventCount events' : '')
        : (eventCount > 0 ? '$eventCount events' : null);

    return Column(
      children: [
        ListTile(
          title: Text(topic?.fullDisplayName ?? suggestion.label),
          subtitle:
              subtitle != null ? Text(subtitle, style: subtitleStyle) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.explore,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Related topics',
                onPressed: () => _loadRelatedTopics(suggestion.id),
              ),
              Switch(
                value: isSubscribed,
                onChanged: (_) => _toggleSubscription(suggestion.id),
              ),
            ],
          ),
        ),
        if (isExpanded) _buildRelatedTopicsPanel(),
      ],
    );
  }

  Widget _buildRelatedTopicsPanel() {
    if (_loadingRelated) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_relatedTopics.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: Text(
          'No related topics found',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Related Topics',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          ..._relatedTopics.map((related) {
            final isSubscribed = _subscribedTopicIds.contains(related.id);

            return ListTile(
              dense: true,
              title: Text(related.fullDisplayName),
              trailing: Switch(
                value: isSubscribed,
                onChanged: (_) => _toggleSubscription(related.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
              'Try selecting a different category',
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
