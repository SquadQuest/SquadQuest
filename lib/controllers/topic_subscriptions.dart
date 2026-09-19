import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
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
        .listen(_onData, onError: _onStreamError);

    // cancel subscription when provider is disposed
    ref.onDispose(() {
      subscription.cancel();
    });

    return future;
  }

  void _onData(List<Map<String, dynamic>> data) async {
    try {
      state = AsyncValue.data(
          data.map((row) => row['topic'] as TopicID).toList());
    } catch (error, stackTrace) {
      _onStreamError(error, stackTrace);
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    logger.e('Failed to load topic subscriptions',
        error: error, stackTrace: stackTrace);

    // settle build()'s future so the UI can show an error instead of spinning
    // forever, but never replace data we already have
    if (!state.hasValue) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
