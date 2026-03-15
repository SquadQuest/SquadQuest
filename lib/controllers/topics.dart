import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:squadquest/common.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/topics_cache.dart';
import 'package:squadquest/models/topic.dart';

final topicsProvider =
    AsyncNotifierProvider<TopicsController, List<Topic>>(TopicsController.new);

class TopicSuggestion {
  final String id;
  final String name;
  final String? displayName;
  final double similarity;

  TopicSuggestion({
    required this.id,
    required this.name,
    this.displayName,
    required this.similarity,
  });

  String get label => displayName ?? name;
}

class SuggestTopicsResult {
  final List<TopicSuggestion> suggestions;
  final List<double> embedding;

  SuggestTopicsResult({
    required this.suggestions,
    required this.embedding,
  });
}

class TopicsController extends AsyncNotifier<List<Topic>> {
  @override
  Future<List<Topic>> build() async {
    return fetch();
  }

  Future<List<Topic>> fetch() async {
    final supabase = ref.read(supabaseClientProvider);
    final topicsCache = ref.read(topicsCacheProvider.notifier);

    final data =
        await supabase.from('topics').select().order('name', ascending: true);

    final topics = await hydrate(data);

    // add loaded topics to topics cache
    topicsCache.cacheTopics(topics);

    return topics;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(fetch);
  }

  Future<List<Topic>> hydrate(List<Map<String, dynamic>> data) async {
    return data.map(Topic.fromMap).toList();
  }

  Future<Topic> save(Topic topic) async {
    assert(topic.id == null, 'Cannot create a topic with an ID');
    assert(topic.name.trim().isNotEmpty, 'Cannot create a topic with no name');

    final supabase = ref.read(supabaseClientProvider);

    final Map topicData = topic.toMap();

    final savedData =
        await supabase.from('topics').insert(topicData).select().single();

    final savedTopic = (await hydrate([savedData])).first;

    // update loaded topics with newly created one
    if (state.hasValue && state.value != null) {
      state = AsyncValue.data(updateListWithRecord<Topic>(state.value!,
          (existing) => existing.id == savedTopic.id, savedTopic));
    }

    return savedTopic;
  }

  /// Fast trigram search for typeahead
  Future<List<TopicSuggestion>> searchTrigram(String query,
      {int maxResults = 10}) async {
    final supabase = ref.read(supabaseClientProvider);

    final data = await supabase.rpc('search_topics_trigram', params: {
      'query': query,
      'max_results': maxResults,
    });

    return (data as List).map((row) {
      return TopicSuggestion(
        id: row['id'] as String,
        name: row['name'] as String,
        displayName: row['display_name'] as String?,
        similarity: (row['similarity'] as num).toDouble(),
      );
    }).toList();
  }

  /// Semantic search via the suggest-topics edge function
  Future<SuggestTopicsResult> suggestTopics(String query) async {
    final supabase = ref.read(supabaseClientProvider);
    final session = supabase.auth.currentSession;

    final response = await http.post(
      Uri.parse(
          '${supabase.rest.url.replaceAll('/rest/v1', '')}/functions/v1/suggest-topics'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session?.accessToken ?? ''}',
      },
      body: jsonEncode({'query': query}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get topic suggestions: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final suggestions = (body['suggestions'] as List).map((row) {
      return TopicSuggestion(
        id: row['id'] as String,
        name: row['name'] as String,
        displayName: row['display_name'] as String?,
        similarity: (row['similarity'] as num).toDouble(),
      );
    }).toList();

    final embedding =
        (body['embedding'] as List).map((e) => (e as num).toDouble()).toList();

    return SuggestTopicsResult(
      suggestions: suggestions,
      embedding: embedding,
    );
  }

  /// Get related topics for a given topic (neighborhoods)
  Future<List<TopicSuggestion>> getRelatedTopics(String topicId,
      {int maxResults = 5}) async {
    final supabase = ref.read(supabaseClientProvider);

    final data = await supabase.rpc('get_related_topics', params: {
      'topic_id': topicId,
      'max_results': maxResults,
    });

    return (data as List).map((row) {
      return TopicSuggestion(
        id: row['id'] as String,
        name: row['name'] as String,
        displayName: row['display_name'] as String?,
        similarity: (row['similarity'] as num).toDouble(),
      );
    }).toList();
  }
}
