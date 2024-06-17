import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/topics.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';

final eventDateFormat = DateFormat('E, MMM d');
final eventTimeFormat = DateFormat('h:mm a');

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
    final supabase = ref.read(supabaseClientProvider);

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

    final supabase = ref.read(supabaseClientProvider);

    final Map instanceData = instance.toMap();

    // if topic is blank but the instance had a topic model, it's a phantom we need to upsert first
    if (instanceData['topic'] == null && instance.topic != null) {
      final Topic insertedTopic =
          await ref.read(topicsProvider.notifier).createTopic(instance.topic!);

      instanceData['topic'] = insertedTopic.id;
    }

    // create event instance
    final insertedData = await supabase
        .from('instances')
        .insert(instanceData)
        .select(_defaultSelect)
        .single();

    final insertedInstance = Instance.fromMap(insertedData);

    // update loaded instances with newly created one
    if (loadedInstances != null) {
      List<Instance> updatedList = [...loadedInstances, insertedInstance];
      state = AsyncValue.data(updatedList);
    }

    // create rsvp
    await ref
        .read(rsvpsProvider.notifier)
        .save(insertedInstance.id!, InstanceMemberStatus.yes);

    return insertedInstance;
  }

  Future<Instance> getById(InstanceID id) async {
    final List<Instance>? loadedInstances =
        state.hasValue ? state.asData!.value : null;

    if (loadedInstances != null) {
      return loadedInstances.firstWhere((instance) => instance.id == id);
    }

    final supabase = ref.read(supabaseClientProvider);

    try {
      final data = await supabase
          .from('instances')
          .select(_defaultSelect)
          .eq('id', id)
          .single();

      return Instance.fromMap(data);
    } catch (error) {
      throw 'Could not load instance with ID $id';
    }
  }
}
