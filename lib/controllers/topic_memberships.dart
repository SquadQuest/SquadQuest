import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/common.dart';

import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/topics_cache.dart';
import 'package:squadquest/models/topic_member.dart';

final topicMembershipsProvider =
    AsyncNotifierProvider<TopicMembershipsController, List<MyTopicMembership>>(
        TopicMembershipsController.new);

class TopicMembershipsController
    extends AsyncNotifier<List<MyTopicMembership>> {
  @override
  Future<List<MyTopicMembership>> build() async {
    return fetch();
  }

  Future<List<MyTopicMembership>> fetch() async {
    final supabase = ref.read(supabaseClientProvider);

    final data = await supabase.from('my_topic_memberships').select('*');

    return hydrate(data);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(fetch);
  }

  Future<List<MyTopicMembership>> hydrate(
      List<Map<String, dynamic>> data) async {
    final topicsCache = ref.read(topicsCacheProvider.notifier);

    // populate topic data
    await topicsCache.populateData(data, [(idKey: 'topic', modelKey: 'topic')]);

    return data.map(MyTopicMembership.fromMap).toList();
  }

  Future<MyTopicMembership> saveSubscribed(
      MyTopicMembership topicMembership, bool subscribed) async {
    final supabase = ref.read(supabaseClientProvider);

    if (subscribed) {
      await supabase.from('topic_members').upsert({
        'topic': topicMembership.topic.id,
        'member': supabase.auth.currentUser!.id
      });
    } else {
      await supabase
          .from('topic_members')
          .delete()
          .eq('topic', topicMembership.topic.id!)
          .eq('member', supabase.auth.currentUser!.id);
    }

    // create new record
    final updatedTopicMembership = MyTopicMembership(
        topic: topicMembership.topic,
        subscribed: subscribed,
        events: topicMembership.events);

    // update loaded memberships with created/updated one
    if (state.hasValue && state.value != null) {
      state = AsyncValue.data(updateListWithRecord<MyTopicMembership>(
          state.value!,
          (existing) => existing.topic == topicMembership.topic,
          updatedTopicMembership));
    }

    return updatedTopicMembership;
  }
}
