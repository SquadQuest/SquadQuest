import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/topics.dart';
import 'package:squadquest/controllers/topic_memberships.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/topic_member.dart';

class TopicsScreen extends ConsumerStatefulWidget {
  const TopicsScreen({super.key});

  @override
  ConsumerState<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends ConsumerState<TopicsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<TopicID, bool> pendingChanges = {};

  // Search results
  List<TopicSuggestion> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _searchDebounce;

  // Expanded topic for neighborhoods
  String? _expandedTopicId;
  List<TopicSuggestion> _relatedTopics = [];
  bool _loadingRelated = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim());

    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(_searchQuery);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _isSearching = true);

    try {
      // Run trigram search first
      final trigramResults =
          await ref.read(topicsProvider.notifier).searchTrigram(query);

      if (!mounted || _searchQuery != query) return;

      setState(() {
        _searchResults = trigramResults;
        _hasSearched = true;
      });

      // If trigram didn't find much, run semantic search
      if (trigramResults.length < 3 && query.length >= 3) {
        try {
          final semanticResult =
              await ref.read(topicsProvider.notifier).suggestTopics(query);

          if (!mounted || _searchQuery != query) return;

          // Merge results, deduplicating
          final existingIds = _searchResults.map((s) => s.id).toSet();
          final newResults = semanticResult.suggestions
              .where((s) => !existingIds.contains(s.id))
              .toList();

          setState(() {
            _searchResults = [..._searchResults, ...newResults];
          });
        } catch (_) {
          // Semantic search is optional enhancement
        }
      }
    } catch (_) {
      // Fall back to client-side filtering
      _fallbackSearch(query);
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _fallbackSearch(String query) {
    final topicMemberships = ref.read(topicMembershipsProvider).valueOrNull;
    if (topicMemberships == null) return;

    final lowerQuery = query.toLowerCase();
    setState(() {
      _searchResults = topicMemberships
          .where((tm) =>
              tm.topic.name.toLowerCase().contains(lowerQuery) ||
              (tm.topic.displayName?.toLowerCase().contains(lowerQuery) ??
                  false))
          .map((tm) => TopicSuggestion(
                id: tm.topic.id!,
                name: tm.topic.name,
                displayName: tm.topic.displayName,
                similarity: 1.0,
              ))
          .toList();
      _hasSearched = true;
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

    try {
      final related =
          await ref.read(topicsProvider.notifier).getRelatedTopics(topicId);
      if (mounted && _expandedTopicId == topicId) {
        setState(() {
          _relatedTopics = related;
          _loadingRelated = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingRelated = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final topicMembershipsList = ref.watch(topicMembershipsProvider);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
            child: topicMembershipsList.when(
              data: (topicMemberships) {
                // Build subscribed topics list
                final subscribedTopics = topicMemberships
                    .where((tm) => pendingChanges.containsKey(tm.topic.id)
                        ? pendingChanges[tm.topic.id]!
                        : tm.subscribed)
                    .toList();

                return ListView(
                  children: [
                    // Search results
                    if (_hasSearched && _searchResults.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          'Search Results',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      ..._searchResults.map(
                          (s) => _buildSearchResultTile(s, topicMemberships)),
                    ],

                    if (_hasSearched && _searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No topics found. Try different search terms.',
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // My Topics section
                    if (subscribedTopics.isNotEmpty) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          'My Topics',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      ...subscribedTopics.map(
                          (tm) => _buildSubscribedTile(tm, topicMemberships)),
                    ],

                    // Empty state when no search and no subscriptions
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(
      TopicSuggestion suggestion, List<MyTopicMembership> allMemberships) {
    // Find if user is subscribed to this topic
    final membership =
        allMemberships.where((tm) => tm.topic.id == suggestion.id).firstOrNull;
    final isSubscribed = pendingChanges.containsKey(suggestion.id)
        ? pendingChanges[suggestion.id]!
        : (membership?.subscribed ?? false);
    final isPending = pendingChanges.containsKey(suggestion.id);
    final isExpanded = _expandedTopicId == suggestion.id;

    return Column(
      children: [
        ListTile(
          title: Text(suggestion.label),
          subtitle: membership?.events != null && membership!.events! > 0
              ? Text('${membership.events} events')
              : null,
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
                onChanged: isPending
                    ? null
                    : (value) {
                        if (membership != null) {
                          _onTopicCheckboxChanged(membership, value);
                        } else {
                          // Create a temporary membership for subscribing
                          _onTopicCheckboxChanged(
                            MyTopicMembership(
                              topic: Topic(
                                id: suggestion.id,
                                name: suggestion.name,
                                displayName: suggestion.displayName,
                              ),
                              subscribed: false,
                              events: 0,
                            ),
                            value,
                          );
                        }
                      },
              ),
            ],
          ),
        ),

        // Related topics panel
        if (isExpanded) _buildRelatedTopicsPanel(allMemberships),
      ],
    );
  }

  Widget _buildSubscribedTile(
      MyTopicMembership membership, List<MyTopicMembership> allMemberships) {
    final isSubscribed = pendingChanges.containsKey(membership.topic.id)
        ? pendingChanges[membership.topic.id]!
        : membership.subscribed;
    final isPending = pendingChanges.containsKey(membership.topic.id);
    final isExpanded = _expandedTopicId == membership.topic.id;

    return Column(
      children: [
        ListTile(
          title: Text(membership.topic.label),
          subtitle: membership.events != null && membership.events! > 0
              ? Text('${membership.events} events')
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.explore,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Related topics',
                onPressed: () => _loadRelatedTopics(membership.topic.id!),
              ),
              Switch(
                value: isSubscribed,
                onChanged: isPending
                    ? null
                    : (value) => _onTopicCheckboxChanged(membership, value),
              ),
            ],
          ),
        ),
        if (isExpanded) _buildRelatedTopicsPanel(allMemberships),
      ],
    );
  }

  Widget _buildRelatedTopicsPanel(List<MyTopicMembership> allMemberships) {
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
            final membership = allMemberships
                .where((tm) => tm.topic.id == related.id)
                .firstOrNull;
            final isSubscribed = pendingChanges.containsKey(related.id)
                ? pendingChanges[related.id]!
                : (membership?.subscribed ?? false);
            final isPending = pendingChanges.containsKey(related.id);

            return ListTile(
              dense: true,
              title: Text(related.label),
              trailing: Switch(
                value: isSubscribed,
                onChanged: isPending
                    ? null
                    : (value) {
                        if (membership != null) {
                          _onTopicCheckboxChanged(membership, value);
                        } else {
                          _onTopicCheckboxChanged(
                            MyTopicMembership(
                              topic: Topic(
                                id: related.id,
                                name: related.name,
                                displayName: related.displayName,
                              ),
                              subscribed: false,
                              events: 0,
                            ),
                            value,
                          );
                        }
                      },
              ),
            );
          }),
        ],
      ),
    );
  }

  void _onTopicCheckboxChanged(
      MyTopicMembership topicMembership, bool? value) async {
    // mark as pending
    setState(() {
      pendingChanges[topicMembership.topic.id!] = value == true;
    });

    // write to database
    try {
      await ref
          .read(topicMembershipsProvider.notifier)
          .saveSubscribed(topicMembership, value == true);
    } catch (error) {
      loggerWithStack.e(error);
    }

    // unmark as pending
    setState(() {
      pendingChanges.remove(topicMembership.topic.id);
    });
  }
}
