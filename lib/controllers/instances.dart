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
    .family<Instance?, InstanceID>((ref, instanceId) async {
  final instancesController = ref.read(instancesProvider.notifier);
  return instancesController.getById(instanceId);
});

final eventPointsProvider = FutureProvider.autoDispose
    .family<EventPoints?, InstanceID>((ref, instanceId) async {
  final supabase = ref.read(supabaseClientProvider);
  final eventPoints = await supabase
      .from('instance_points')
      .select()
      .eq('id', instanceId)
      .maybeSingle();

  return eventPoints == null ? null : EventPoints.fromMap(eventPoints);
});

class InstancesController extends AsyncNotifier<List<Instance>> {
  @override
  Future<List<Instance>> build() async {
    final supabase = ref.read(supabaseClientProvider);

    // subscribe to changes
    supabase.from('instances').stream(primaryKey: ['id']).listen((data) async {
      // convert to model instances
      final instances = await hydrate(data);

      // convert to model instances and update state
      state = AsyncValue.data(instances);

      // invalidate event details providers
      for (final instance in instances) {
        final instanceProvider = eventDetailsProvider(instance.id);
        if (ref.exists(instanceProvider)) {
          ref.invalidate(instanceProvider);
        }
      }
    });

    return future;
  }

  Future<List<Instance>> fetch() async {
    final supabase = ref.read(supabaseClientProvider);

    final data = await supabase.from('instances').select();

    return hydrate(data);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(fetch);
  }

  Future<List<Instance>> hydrate(List<Map<String, dynamic>> data) async {
    final profilesCache = ref.read(profilesCacheProvider.notifier);
    final topicsCache = ref.read(topicsCacheProvider.notifier);

    return safeHydrateList<Instance>(
      data: data,
      populateData: (records) async {
        // populate profile and topic data
        await profilesCache.populateData(
            records, [(idKey: 'created_by', modelKey: 'created_by')]);
        await topicsCache
            .populateData(records, [(idKey: 'topic', modelKey: 'topic')]);
      },
      fromMap: Instance.fromMap,
      context: 'Instance',
    );
  }

  Future<Instance?> getById(InstanceID id) async {
    final List<Instance>? loadedInstances =
        state.hasValue ? state.asData!.value : null;

    // try to get the instance from the controller's loaded list first
    final Instance? loadedInstance = loadedInstances
        ?.cast<Instance?>()
        .firstWhereOrNull((instance) => instance!.id == id);

    if (loadedInstance != null) {
      return loadedInstance;
    }

    // fall back on querying Superbase
    final supabase = ref.read(supabaseClientProvider);

    try {
      final data =
          await supabase.from('instances').select().eq('id', id).single();

      final instances = await hydrate([data]);
      return instances.isEmpty ? null : instances.first;
    } catch (error) {
      logger.e('Could not load instance with ID $id', error: error);
      return null;
    }
  }

  Future<Instance?> save(Instance instance) async {
    final supabase = ref.read(supabaseClientProvider);

    final Map instanceData = instance.toMap();

    // if topic is blank but the instance had a topic model, it's a phantom we need to upsert first
    if (instanceData['topic'] == null && instance.topic != null) {
      final Topic? insertedTopic =
          await ref.read(topicsProvider.notifier).save(instance.topic!);

      if (insertedTopic != null) {
        instanceData['topic'] = insertedTopic.id;
      }
    }

    try {
      // create event instance
      final savedData = await supabase
          .from('instances')
          .upsert(instanceData)
          .select()
          .single();

      final instances = await hydrate([savedData]);
      if (instances.isEmpty) return null;
      final savedInstance = instances.first;

      // update loaded instances with newly created one
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data(updateListWithRecord<Instance>(state.value!,
            (existing) => existing.id == savedInstance.id, savedInstance));
      }

      // create rsvp
      await ref
          .read(rsvpsProvider.notifier)
          .save(savedInstance.id, InstanceMemberStatus.yes);

      return savedInstance;
    } catch (error) {
      logger.e('Error saving instance', error: error);
      return null;
    }
  }

  Future<Instance?> patch(InstanceID id, Map<String, dynamic> patchData) async {
    logger.i({'instance:patch': patchData});

    try {
      final updatedData = await ref
          .read(supabaseClientProvider)
          .from('instances')
          .update(patchData)
          .eq('id', id)
          .select()
          .single();

      final instances = await hydrate([updatedData]);
      if (instances.isEmpty) return null;
      final updatedInstance = instances.first;

      // update loaded instances with newly created one
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data(updateListWithRecord<Instance>(state.value!,
            (existing) => existing.id == updatedInstance.id, updatedInstance));
      }

      return updatedInstance;
    } catch (error) {
      loggerWithStack.e({'error patching instance': error});
      return null;
    }
  }

  Future<Instance?> fetchFacebookEventData(String facebookUrl) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke('scrape-facebook-event',
          method: HttpMethod.get, queryParameters: {'url': facebookUrl});

      final instances = await hydrate([response.data]);
      return instances.isEmpty ? null : instances.first;
    } catch (error) {
      logger.e('Error fetching Facebook event data', error: error);
      return null;
    }
  }
}
