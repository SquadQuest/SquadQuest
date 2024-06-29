import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/services/topics_cache.dart';
import 'package:squadquest/controllers/topics.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/event_points.dart';

final eventDateFormat = DateFormat('E, MMM d');
final eventTimeFormat = DateFormat('h:mm a');

final instancesProvider =
    AsyncNotifierProvider<InstancesController, List<Instance>>(
        InstancesController.new);

final eventDetailsProvider = FutureProvider.autoDispose
    .family<Instance, InstanceID>((ref, instanceId) async {
  final instancesController = ref.read(instancesProvider.notifier);
  return instancesController.getById(instanceId);
});

final eventPointsProvider = FutureProvider.autoDispose
    .family<EventPoints?, InstanceID>((ref, instanceId) async {
  logger.d('eventPointsProvider initializing for $instanceId');
  final supabase = ref.read(supabaseClientProvider);
  final eventPoints = await supabase
      .from('instance_points')
      .select()
      .eq('id', instanceId)
      .maybeSingle();

  return eventPoints == null ? null : EventPoints.fromMap(eventPoints);
  ;
});

class InstancesController extends AsyncNotifier<List<Instance>> {
  static const _defaultSelect = '*, topic(*), created_by(*)';

  @override
  Future<List<Instance>> build() async {
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

      // convert to model instances
      final instances = populatedData.map(Instance.fromMap).toList();

      // convert to model instances and update state
      state = AsyncValue.data(instances);

      // invalidate event details providers
      for (final instance in instances) {
        final instanceProvider = eventDetailsProvider(instance.id!);
        if (ref.exists(instanceProvider)) {
          ref.invalidate(instanceProvider);
        }
      }
    });

    return future;
  }

  Future<List<Instance>> fetch() async {
    final supabase = ref.read(supabaseClientProvider);

    final instances = await supabase
        .from('instances')
        .select(_defaultSelect)
        .withConverter((data) => data.map(Instance.fromMap).toList());

    // populate profile and topic caches
    for (final instance in instances) {
      ref
          .read(profilesCacheProvider.notifier)
          .cacheProfiles([instance.createdBy!]);
      ref.read(topicsCacheProvider.notifier).cacheTopics([instance.topic!]);
    }

    return instances;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(fetch);
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

  Future<Instance> save(Instance instance) async {
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

  Future<Instance> patch(InstanceID id, Map<String, dynamic> patchData) async {
    logger.i({'instance:patch': patchData});

    try {
      final updatedData = await ref
          .read(supabaseClientProvider)
          .from('instances')
          .update(patchData)
          .eq('id', id)
          .select(_defaultSelect)
          .single();

      final updatedInstance = Instance.fromMap(updatedData);

      // update loaded instances with newly created one
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data(updateListWithRecord<Instance>(state.value!,
            (existing) => existing.id == updatedInstance.id, updatedInstance));
      }

      return updatedInstance;
    } catch (error) {
      loggerWithStack.e({'error patching instance': error});
      rethrow;
    }
  }
}
