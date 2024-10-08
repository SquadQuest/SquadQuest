import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/topics_cache.dart';
import 'package:squadquest/models/topic.dart';

final topicsProvider =
    AsyncNotifierProvider<TopicsController, List<Topic>>(TopicsController.new);

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
    assert(topic.name.trim().isNotEmpty, 'Cannot create a topic no name');

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
}
