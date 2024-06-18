import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/topics_cache.dart';
import 'package:squadquest/models/topic.dart';

final topicsProvider =
    AsyncNotifierProvider<TopicsController, List<Topic>>(TopicsController.new);

class TopicsController extends AsyncNotifier<List<Topic>> {
  static const _defaultSelect = '*';

  @override
  Future<List<Topic>> build() async {
    return fetch();
  }

  Future<List<Topic>> fetch() async {
    final supabase = ref.read(supabaseClientProvider);
    final topicsCache = ref.read(topicsCacheProvider.notifier);

    final topics = await supabase
        .from('topics')
        .select(_defaultSelect)
        .order('name', ascending: true)
        .withConverter((data) => data.map(Topic.fromMap).toList());

    // add loaded topics to topics cache
    topicsCache.cacheTopics(topics);

    return topics;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(fetch);
  }

  Future<Topic> createTopic(Topic topic) async {
    assert(topic.id == null, 'Cannot create a topic with an ID');

    final List<Topic>? loadedTopics =
        state.hasValue ? state.asData!.value : null;

    final supabase = ref.read(supabaseClientProvider);

    final Map topicData = topic.toMap();

    final insertedData =
        await supabase.from('topics').insert(topicData).select(_defaultSelect);

    final insertedTopic = Topic.fromMap(insertedData.first);

    // update loaded topics with newly created one
    if (loadedTopics != null) {
      state = AsyncValue.data([...loadedTopics, insertedTopic]);
    }

    return insertedTopic;
  }
}
