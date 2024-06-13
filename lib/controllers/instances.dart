import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/services/supabase.dart';
import 'package:squad_quest/controllers/topics.dart';
import 'package:squad_quest/models/instance.dart';
import 'package:squad_quest/models/topic.dart';

final eventDateFormat = DateFormat('E, MMM d');
final eventTimeFormat = DateFormat('h:mm a');

final instancesProvider =
    AsyncNotifierProvider<InstancesController, List<Instance>>(
        InstancesController.new);

class InstancesController extends AsyncNotifier<List<Instance>> {
  static const _defaultSelect = '*, topic(*), created_by(*)';
  // static const _defaultMemberSelect = '*, member(*)';

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
        .select(_defaultSelect)
        .single();

    final insertedInstance = Instance.fromMap(insertedData);

    // update loaded topics with newly created one
    if (loadedInstances != null) {
      List<Instance> updatedList = [...loadedInstances, insertedInstance];
      state = AsyncValue.data(updatedList);
    }

    return insertedInstance;
  }

  Future<Instance> getById(InstanceID id) async {
    final List<Instance>? loadedInstances =
        state.hasValue ? state.asData!.value : null;

    if (loadedInstances != null) {
      return loadedInstances.firstWhere((instance) => instance.id == id);
    }

    final supabase = ref.read(supabaseProvider);

    final data = await supabase
        .from('instances')
        .select(_defaultSelect)
        .eq('id', id)
        .single();

    return Instance.fromMap(data);
  }

  Future<InstanceMember?> rsvp(
      Instance instance, InstanceMemberStatus? status) async {
    final supabase = ref.read(supabaseProvider);

    try {
      final response = await supabase.functions.invoke('rsvp',
          body: {'instance_id': instance.id, 'status': status?.name});

      final instanceMember = response.data['status'] == null
          ? null
          : InstanceMember.fromMap(response.data);

      return instanceMember;
    } on FunctionException catch (error) {
      throw error.details.toString().replaceAll(RegExp(r'^[a-z\-]+: '), '');
    }
  }
}
