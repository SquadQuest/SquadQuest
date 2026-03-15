import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/models/topic.dart';
import 'package:squadquest/controllers/topics.dart';

class FormTopicPicker extends ConsumerStatefulWidget {
  final String labelText;
  final Topic? initialValue;
  final StateProvider<Topic?>? valueProvider;
  final ValueChanged<Topic>? onChanged;
  final bool required;

  const FormTopicPicker({
    super.key,
    this.labelText = 'Time',
    this.initialValue,
    this.valueProvider,
    this.onChanged,
    this.required = true,
  });

  @override
  ConsumerState<FormTopicPicker> createState() => _FormTopicPickerState();
}

class _FormTopicPickerState extends ConsumerState<FormTopicPicker> {
  StateProvider<Topic?>? _valueProvider;
  final _formFieldKey = GlobalKey<FormFieldState>();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  Topic? _activeTopic;

  // Search state
  List<TopicSuggestion> _trigramResults = [];
  List<TopicSuggestion> _semanticResults = [];
  List<double>? _lastEmbedding;
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _trigramDebounce;
  Timer? _semanticDebounce;

  void _onTopicSelected(Topic value) {
    _textController.text = value.label;

    ref.read(_valueProvider!.notifier).state = value;

    if (_activeTopic == null || value.name != _activeTopic!.name) {
      _activeTopic = value;
      if (widget.onChanged != null) {
        widget.onChanged!(value);
      }
    }

    // Clear search results and unfocus
    setState(() {
      _trigramResults = [];
      _semanticResults = [];
      _hasSearched = false;
    });
    FocusScope.of(context).nextFocus();
  }

  void _onSearchChanged(String value) {
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _trigramResults = [];
        _semanticResults = [];
        _hasSearched = false;
        _lastEmbedding = null;
      });
      return;
    }

    // Trigram search with 200ms debounce
    _trigramDebounce?.cancel();
    _trigramDebounce = Timer(const Duration(milliseconds: 200), () {
      _runTrigramSearch(query);
    });

    // Semantic search with 500ms debounce, minimum 3 chars
    _semanticDebounce?.cancel();
    if (query.length >= 3) {
      _semanticDebounce = Timer(const Duration(milliseconds: 500), () {
        _runSemanticSearch(query);
      });
    }
  }

  Future<void> _runTrigramSearch(String query) async {
    try {
      final results =
          await ref.read(topicsProvider.notifier).searchTrigram(query);
      if (mounted) {
        setState(() {
          _trigramResults = results;
          _hasSearched = true;
        });
      }
    } catch (_) {
      // Fall back to client-side search on error
      _fallbackClientSearch(query);
    }
  }

  Future<void> _runSemanticSearch(String query) async {
    if (_trigramResults.length >= 3) return; // Skip if trigram found enough

    setState(() => _isSearching = true);

    try {
      final result =
          await ref.read(topicsProvider.notifier).suggestTopics(query);
      if (mounted) {
        setState(() {
          _semanticResults = result.suggestions;
          _lastEmbedding = result.embedding;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _fallbackClientSearch(String query) async {
    final topicsList = await ref.read(topicsProvider.future);
    final lowerQuery = query.toLowerCase();
    if (mounted) {
      setState(() {
        _trigramResults = topicsList
            .where((t) => t.name.toLowerCase().contains(lowerQuery))
            .map((t) => TopicSuggestion(
                  id: t.id!,
                  name: t.name,
                  displayName: t.displayName,
                  similarity: 1.0,
                ))
            .toList();
        _hasSearched = true;
      });
    }
  }

  String _generateSlug(String displayName) {
    return displayName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s\-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  Future<void> _createNewTopic() async {
    final displayName = _textController.text.trim();
    if (displayName.isEmpty) return;

    final slug = _generateSlug(displayName);

    // Check for high-similarity matches that should trigger a warning
    final highMatches = [
      ..._trigramResults.where((s) => s.similarity > 0.7),
      ..._semanticResults.where((s) => s.similarity > 0.7),
    ];

    if (highMatches.isNotEmpty && mounted) {
      final confirmed = await showDialog<bool>(
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final newTopic = Topic(
      id: null,
      name: slug,
      displayName: displayName,
      embedding: _lastEmbedding,
    );

    try {
      final savedTopic = await ref.read(topicsProvider.notifier).save(newTopic);
      _onTopicSelected(savedTopic);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create topic: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _valueProvider = widget.valueProvider ??
        StateProvider<Topic?>((ref) => widget.initialValue);

    final initialValue = ref.read(_valueProvider!);

    if (initialValue != null) {
      _textController.text = initialValue.label;
    }

    _textController.addListener(() {
      _onSearchChanged(_textController.text);
    });
  }

  @override
  void dispose() {
    _trigramDebounce?.cancel();
    _semanticDebounce?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Combine and deduplicate results
    final allSuggestionIds = <String>{};
    final combinedResults = <TopicSuggestion>[];

    for (final result in _trigramResults) {
      if (allSuggestionIds.add(result.id)) {
        combinedResults.add(result);
      }
    }

    // Add semantic results that aren't already in trigram results
    final semanticOnly = <TopicSuggestion>[];
    for (final result in _semanticResults) {
      if (allSuggestionIds.add(result.id)) {
        semanticOnly.add(result);
      }
    }

    final showCreateButton =
        _hasSearched && _textController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          key: _formFieldKey,
          controller: _textController,
          focusNode: _focusNode,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: widget.required
                ? 'Topic for event'
                : 'Topic for event (optional)',
            prefixIcon: const Icon(Icons.category),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _textController.clear();
                          setState(() {
                            _trigramResults = [];
                            _semanticResults = [];
                            _hasSearched = false;
                            _lastEmbedding = null;
                          });
                        },
                      )
                    : null,
            filled: true,
            fillColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withAlpha(80),
          ),
          validator: (value) {
            if (widget.required && (_activeTopic == null)) {
              return 'Please select or create a topic';
            }
            return null;
          },
        ),

        // Search results
        if (combinedResults.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                ...combinedResults.map((s) => _buildSuggestionTile(s)),
                if (semanticOnly.isNotEmpty) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'Similar topics',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  ...semanticOnly.map((s) => _buildSuggestionTile(s)),
                ],
              ],
            ),
          ),
        ],

        // Create new topic button
        if (showCreateButton) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _createNewTopic,
            icon: const Icon(Icons.add, size: 18),
            label: Text('Create "${_textController.text.trim()}"'),
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestionTile(TopicSuggestion suggestion) {
    final similarity = suggestion.similarity;
    final TextStyle? subtitleStyle;

    if (similarity > 0.85) {
      subtitleStyle = TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontSize: 12,
      );
    } else if (similarity > 0.7) {
      subtitleStyle = TextStyle(
        color: Theme.of(context).colorScheme.tertiary,
        fontSize: 12,
      );
    } else {
      subtitleStyle = null;
    }

    return ListTile(
      dense: true,
      title: Text(suggestion.label),
      subtitle: similarity > 0.7
          ? Text(
              similarity > 0.85
                  ? 'This topic already exists'
                  : 'Did you mean this?',
              style: subtitleStyle,
            )
          : null,
      onTap: () {
        // Select the existing topic
        _onTopicSelected(Topic(
          id: suggestion.id,
          name: suggestion.name,
          displayName: suggestion.displayName,
        ));
      },
    );
  }

  @override
  void didUpdateWidget(FormTopicPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.required != oldWidget.required) {
      _formFieldKey.currentState?.validate();
    }
  }
}
