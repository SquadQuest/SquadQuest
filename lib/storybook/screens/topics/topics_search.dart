import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/topics.dart';

// Mock topic data with display names and slugs
class _MockTopic {
  final String id;
  final String slug;
  final String displayName;
  final int events;
  bool subscribed;

  _MockTopic({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.events,
    this.subscribed = false,
  });

  String get label => displayName;
}

// Pre-built mock data
final _allMockTopics = <_MockTopic>[
  _MockTopic(id: 't1', slug: 'running', displayName: 'Running', events: 8),
  _MockTopic(
      id: 't2', slug: 'trail-running', displayName: 'Trail Running', events: 3),
  _MockTopic(id: 't3', slug: 'hiking', displayName: 'Hiking', events: 12),
  _MockTopic(
      id: 't4', slug: 'rock-climbing', displayName: 'Rock Climbing', events: 5),
  _MockTopic(
      id: 't5', slug: 'board-games', displayName: 'Board Games', events: 7),
  _MockTopic(
      id: 't6', slug: 'photography', displayName: 'Photography', events: 4),
  _MockTopic(id: 't7', slug: 'cycling', displayName: 'Cycling', events: 6),
  _MockTopic(
      id: 't8', slug: 'cross-country', displayName: 'Cross Country', events: 2),
  _MockTopic(id: 't9', slug: 'yoga', displayName: 'Yoga', events: 9),
  _MockTopic(id: 't10', slug: 'cooking', displayName: 'Cooking', events: 3),
  _MockTopic(
      id: 't11', slug: 'movie-nights', displayName: 'Movie Nights', events: 5),
  _MockTopic(id: 't12', slug: 'swimming', displayName: 'Swimming', events: 4),
];

// Semantic similarity map: query substring → [(topicId, similarity)]
const _semanticMap = <String, List<(String, double)>>{
  'jog': [('t1', 0.87), ('t2', 0.72)],
  'jogging': [('t1', 0.92), ('t2', 0.78), ('t8', 0.65)],
  'hike': [('t3', 0.90), ('t2', 0.68)],
  'climb': [('t4', 0.88), ('t3', 0.62)],
  'bike': [('t7', 0.85)],
  'exercise': [('t1', 0.75), ('t7', 0.72), ('t9', 0.70), ('t12', 0.68)],
  'outdoor': [('t3', 0.80), ('t2', 0.78), ('t4', 0.75), ('t7', 0.70)],
  'games': [('t5', 0.90), ('t11', 0.60)],
  'food': [('t10', 0.82)],
  'fitness': [('t1', 0.80), ('t9', 0.78), ('t7', 0.75), ('t12', 0.72)],
};

// Related topics (neighborhoods) map: topicId → [topicIds]
const _relatedMap = <String, List<String>>{
  't1': ['t2', 't8', 't7'], // Running → Trail Running, Cross Country, Cycling
  't2': ['t1', 't3', 't8'], // Trail Running → Running, Hiking, Cross Country
  't3': ['t2', 't4'], // Hiking → Trail Running, Rock Climbing
  't4': ['t3', 't2'], // Rock Climbing → Hiking, Trail Running
  't5': ['t11'], // Board Games → Movie Nights
  't7': ['t1', 't12'], // Cycling → Running, Swimming
  't9': ['t1', 't12'], // Yoga → Running, Swimming
};

class TopicsSearchScreen extends ConsumerStatefulWidget {
  const TopicsSearchScreen({super.key});

  @override
  ConsumerState<TopicsSearchScreen> createState() => _TopicsSearchScreenState();
}

class _TopicsSearchScreenState extends ConsumerState<TopicsSearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Search results
  List<TopicSuggestion> _trigramResults = [];
  List<TopicSuggestion> _semanticResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _trigramDebounce;
  Timer? _semanticDebounce;

  // Neighborhoods
  String? _expandedTopicId;
  List<TopicSuggestion> _relatedTopics = [];
  bool _loadingRelated = false;

  // Local subscription state
  final Set<String> _subscribedIds = {'t1', 't3', 't5'};

  // Knob state (read during build, used in async methods)
  bool _simulateSemanticDelay = false;

  // Local copy of topics
  late List<_MockTopic> _topics;

  @override
  void initState() {
    super.initState();
    _topics = _allMockTopics.map((t) {
      final copy = _MockTopic(
        id: t.id,
        slug: t.slug,
        displayName: t.displayName,
        events: t.events,
        subscribed: _subscribedIds.contains(t.id),
      );
      return copy;
    }).toList();
  }

  @override
  void dispose() {
    _trigramDebounce?.cancel();
    _semanticDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  _MockTopic? _topicById(String id) {
    return _topics.where((t) => t.id == id).firstOrNull;
  }

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

    // Trigram with 200ms debounce
    _trigramDebounce?.cancel();
    _trigramDebounce = Timer(const Duration(milliseconds: 200), () {
      _runTrigramSearch(query);
    });

    // Semantic with 500ms debounce
    _semanticDebounce?.cancel();
    if (query.length >= 3) {
      _semanticDebounce = Timer(const Duration(milliseconds: 500), () {
        _runSemanticSearch(query);
      });
    }
  }

  void _runTrigramSearch(String query) {
    final lowerQuery = query.toLowerCase();
    final results = _topics
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

    // Check each key in semantic map for substring match
    for (final entry in _semanticMap.entries) {
      if (lowerQuery.contains(entry.key) || entry.key.contains(lowerQuery)) {
        for (final (topicId, similarity) in entry.value) {
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

    // Brief delay for realism
    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted || _expandedTopicId != topicId) return;

    final relatedIds = _relatedMap[topicId] ?? [];
    final results = relatedIds
        .map((id) => _topicById(id))
        .where((t) => t != null)
        .map((t) => TopicSuggestion(
              id: t!.id,
              name: t.slug,
              displayName: t.displayName,
              similarity: 0.75,
            ))
        .toList();

    setState(() {
      _relatedTopics = results;
      _loadingRelated = false;
    });
  }

  void _toggleSubscription(String topicId) {
    setState(() {
      if (_subscribedIds.contains(topicId)) {
        _subscribedIds.remove(topicId);
      } else {
        _subscribedIds.add(topicId);
      }
      final topic = _topicById(topicId);
      if (topic != null) {
        topic.subscribed = _subscribedIds.contains(topicId);
      }
    });
  }

  void _showCreateDialog() {
    final displayName = _searchController.text.trim();
    if (displayName.isEmpty) return;

    // Check for high-similarity matches
    final highMatches = <TopicSuggestion>[
      ..._trigramResults.where((s) => s.similarity > 0.7),
      ..._semanticResults.where((s) => s.similarity > 0.7),
    ];

    if (highMatches.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Similar topic exists'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
                _createTopic(displayName);
              },
              child: const Text('Create anyway'),
            ),
          ],
        ),
      );
    } else {
      _createTopic(displayName);
    }
  }

  void _createTopic(String displayName) {
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
      events: 0,
      subscribed: true,
    );

    setState(() {
      _topics.add(newTopic);
      _subscribedIds.add(newId);
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

  @override
  Widget build(BuildContext context) {
    final showSubscribed = context.knobs.boolean(
      label: 'Show subscribed topics',
      initial: true,
    );

    _simulateSemanticDelay = context.knobs.boolean(
      label: 'Simulate semantic delay',
      initial: false,
    );

    // Deduplicate combined results
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

    final subscribedTopics =
        _topics.where((t) => _subscribedIds.contains(t.id)).toList();

    final showCreateButton =
        _hasSearched && _searchController.text.trim().isNotEmpty;

    return AppScaffold(
      title: 'Topics',
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'What are you interested in?',
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          Expanded(
            child: ListView(
              children: [
                // Trigram search results
                if (_hasSearched && trigramOnly.isNotEmpty) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Similar Topics',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  ...semanticOnly.map((s) => _buildSearchResultTile(s)),
                ],

                // No results
                if (_hasSearched && trigramOnly.isEmpty && semanticOnly.isEmpty)
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: OutlinedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Create "${_searchController.text.trim()}"'),
                    ),
                  ),

                // My Topics section
                if (showSubscribed && subscribedTopics.isNotEmpty) ...[
                  const Divider(),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'My Topics',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  ...subscribedTopics.map((t) => _buildSubscribedTile(t)),
                ],

                // Empty state
                if (!_hasSearched && subscribedTopics.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withAlpha(128),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Search for topics you\'re interested in to subscribe and get notified about new events',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(TopicSuggestion suggestion) {
    final isSubscribed = _subscribedIds.contains(suggestion.id);
    final isExpanded = _expandedTopicId == suggestion.id;

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

    final topic = _topicById(suggestion.id);
    final eventCount = topic?.events ?? 0;
    final subtitle = subtitleText != null
        ? subtitleText + (eventCount > 0 ? ' · $eventCount events' : '')
        : (eventCount > 0 ? '$eventCount events' : null);

    return Column(
      children: [
        ListTile(
          title: Text(suggestion.label),
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

  Widget _buildSubscribedTile(_MockTopic topic) {
    final isExpanded = _expandedTopicId == topic.id;

    return Column(
      children: [
        ListTile(
          title: Text(topic.label),
          subtitle: topic.events > 0 ? Text('${topic.events} events') : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.explore,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Related topics',
                onPressed: () => _loadRelatedTopics(topic.id),
              ),
              Switch(
                value: true,
                onChanged: (_) => _toggleSubscription(topic.id),
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
            final isSubscribed = _subscribedIds.contains(related.id);

            return ListTile(
              dense: true,
              title: Text(related.label),
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
}
