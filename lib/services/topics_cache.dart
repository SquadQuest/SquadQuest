import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/models/topic.dart';

typedef TopicsCache = Map<TopicID, Topic>;

final topicsCacheProvider =
    NotifierProvider<TopicsCacheService, TopicsCache>(TopicsCacheService.new);

class TopicsCacheService extends Notifier<TopicsCache> {
  @override
  TopicsCache build() {
    return {};
  }

  Future<void> cacheTopics(List<Topic> topics) async {
    for (Topic topic in topics) {
      if (topic.id == null) continue;
      state[topic.id!] = topic;
    }
  }

  Future<List<Map<String, dynamic>>> populateData(
      List<Map<String, dynamic>> data,
      List<({String idKey, String modelKey})> fields) async {
    // build set of missing IDs
    final Set<TopicID> missingIds = {};
    for (final item in data) {
      for (final field in fields) {
        if (item[field.modelKey] is Topic) {
          continue;
        }

        final TopicID topicId = item[field.idKey];
        if (!state.containsKey(topicId)) {
          missingIds.add(topicId);
        }
      }
    }

    // fetch missing topics into cache
    if (missingIds.isNotEmpty) {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('topics')
          .select('*')
          .inFilter('id', missingIds.toList())
          .withConverter((data) => data.map(Topic.fromMap).toList())
          .then(cacheTopics);
    }

    // return hydrated data
    return data.map((Map<String, dynamic> item) {
      for (final field in fields) {
        if (item[field.modelKey] is Topic) {
          continue;
        }

        if (item.containsKey(field.idKey) && item[field.idKey] is TopicID) {
          final Topic? topic = state[item[field.idKey]];
          if (topic != null) {
            item[field.modelKey] = topic;
          }
        }
      }
      return item;
    }).toList();
  }
}
