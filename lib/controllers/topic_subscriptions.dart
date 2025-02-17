import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/models/topic.dart';

final topicSubscriptionsProvider =
    AsyncNotifierProvider<TopicSubscriptionsController, List<TopicID>>(
        TopicSubscriptionsController.new);

class TopicSubscriptionsController extends AsyncNotifier<List<TopicID>> {
  @override
  Future<List<TopicID>> build() async {
    final supabase = ref.read(supabaseClientProvider);

    // subscribe to changes to subscribed topics
    final subscription = supabase
        .from('topic_members')
        .stream(primaryKey: ['topic', 'member'])
        .eq('member', supabase.auth.currentUser!.id)
        .listen((data) async {
          state = AsyncValue.data(
              data.map((row) => row['topic'] as TopicID).toList());
        });

    // cancel subscription when provider is disposed
    ref.onDispose(() {
      subscription.cancel();
    });

    return future;
  }
}
