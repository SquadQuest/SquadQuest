import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/services/topics_cache.dart';
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
    final profilesCache = ref.read(profilesCacheProvider.notifier);
    final topicsCache = ref.read(topicsCacheProvider.notifier);

    // subscribe to changes
    supabase.from('instances').stream(primaryKey: ['id']).listen((data) async {
      // populate created_by field with profile data
      var populatedData = await profilesCache
          .populateData(data, [(idKey: 'created_by', modelKey: 'created_by')]);

      // populate topic field with topic data
      populatedData = await topicsCache
          .populateData(data, [(idKey: 'topic', modelKey: 'topic')]);

      // convert to model instances and update state
      state = AsyncValue.data(populatedData.map(Instance.fromMap).toList());
    });

    return future;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(fetch);
  }

  Future<Instance> createInstance(Instance instance) async {
    assert(instance.id == null, 'Cannot create an instance with an ID');

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
    if (state.hasValue && state.value != null) {
      state = AsyncValue.data(updateListWithRecord<Instance>(state.value!,
          (existing) => existing.id == insertedInstance.id, insertedInstance));
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

    // try to get the instance from the controller's loaded list first
    final Instance? loadedInstance = loadedInstances
        ?.cast<Instance?>()
        .firstWhere((instance) => instance!.id == id, orElse: () => null);

    if (loadedInstance != null) {
      return loadedInstance;
    }

    // fall back on querying Superbase
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
