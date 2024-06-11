import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/services/supabase.dart';
import 'package:squad_quest/models/topic.dart';

final topicsProvider =
    AsyncNotifierProvider<TopicsController, List<Topic>>(TopicsController.new);

class TopicsController extends AsyncNotifier<List<Topic>> {
  @override
  Future<List<Topic>> build() async {
    return fetch();
  }

  Future<List<Topic>> fetch() async {
    final supabase = ref.read(supabaseProvider);

    return supabase
        .from('topics')
        .select('*')
        .order('name', ascending: true)
        .withConverter((data) => data.map(Topic.fromMap).toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(fetch);
  }
}
