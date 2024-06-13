import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/services/supabase.dart';
import 'package:squad_quest/controllers/topics.dart';
import 'package:squad_quest/models/instance.dart';
import 'package:squad_quest/models/topic.dart';

final instancesProvider =
    AsyncNotifierProvider<InstancesController, List<Instance>>(
        InstancesController.new);

class InstancesController extends AsyncNotifier<List<Instance>> {
  static const _defaultSelect = '*, topic(*), created_by(*)';

  @override
  Future<List<Instance>> build() async {
    return fetch();
  }

  Future<List<Instance>> fetch() async {
    final supabase = ref.read(supabaseProvider);

    return supabase
        .from('instances')
        .select(_defaultSelect)
        .order('start_time_min', ascending: true)
        .withConverter((data) => data.map(Instance.fromMap).toList());
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(fetch);
  }

  Future<Instance> createInstance(Instance instance) async {
    assert(instance.id == null, 'Cannot create an instance with an ID');

    final List<Instance>? loadedInstances =
        state.hasValue ? state.asData!.value : null;

    final supabase = ref.read(supabaseProvider);

    final Map instanceData = instance.toMap();

    // if topic is blank but the instance had a topic model, it's a phantom we need to upsert first
    if (instanceData['topic'] == null && instance.topic != null) {
      final Topic insertedTopic =
          await ref.read(topicsProvider.notifier).createTopic(instance.topic!);

      instanceData['topic'] = insertedTopic.id;
    }

    final insertedData = await supabase
        .from('instances')
        .insert(instanceData)
        .select(_defaultSelect);

    final insertedInstance = Instance.fromMap(insertedData.first);

    // update loaded topics with newly created one
    if (loadedInstances != null) {
      List<Instance> updatedList = [...loadedInstances, insertedInstance];
      state = AsyncValue.data(updatedList);
    }

    return insertedInstance;
  }
}
