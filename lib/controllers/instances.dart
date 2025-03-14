import 'dart:async';

import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/services/topics_cache.dart';
import 'package:squadquest/controllers/calendar.dart';
import 'package:squadquest/controllers/settings.dart';
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
    final subscription = supabase
        .from('instances')
        .stream(primaryKey: ['id']).listen((data) async {
      // convert to model instances
      final instances = await hydrate(data);

      // convert to model instances and update state
      state = AsyncValue.data(instances);

      // Trigger calendar sync
      await _triggerCalendarSync(instances);

      // invalidate event details providers
      for (final instance in instances) {
        final instanceProvider = eventDetailsProvider(instance.id!);
        if (ref.exists(instanceProvider)) {
          ref.invalidate(instanceProvider);
        }
      }
    });

    // cancel subscription when provider is disposed
    ref.onDispose(() {
      subscription.cancel();
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

    // populate profile data
    await profilesCache
        .populateData(data, [(idKey: 'created_by', modelKey: 'created_by')]);

    // populate topic data
    await topicsCache.populateData(data, [(idKey: 'topic', modelKey: 'topic')]);

    return data.map(Instance.fromMap).toList();
  }

  Future<Instance> getById(InstanceID id) async {
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

      return (await hydrate([data])).first;
    } catch (error) {
      throw 'Could not load instance with ID $id';
    }
  }

  Future<Instance> save(Instance instance) async {
    final supabase = ref.read(supabaseClientProvider);

    final Map instanceData = instance.toMap();

    // if topic is blank but the instance had a topic model, it's a phantom we need to upsert first
    if (instanceData['topic'] == null && instance.topic != null) {
      final Topic insertedTopic =
          await ref.read(topicsProvider.notifier).save(instance.topic!);

      instanceData['topic'] = insertedTopic.id;
    }

    // create event instance
    final savedData =
        await supabase.from('instances').upsert(instanceData).select().single();

    final savedInstance = (await hydrate([savedData])).first;

    // update loaded instances with newly created one
    if (state.hasValue && state.value != null) {
      state = AsyncValue.data(updateListWithRecord<Instance>(state.value!,
          (existing) => existing.id == savedInstance.id, savedInstance));
    }

    // create rsvp with calendar sync
    await ref
        .read(rsvpsProvider.notifier)
        .save(savedInstance, InstanceMemberStatus.yes);

    return savedInstance;
  }

  Future<void> _triggerCalendarSync(List<Instance> instances) async {
    // Only sync if calendar writing is enabled
    final calendarWritingEnabled = ref.read(calendarWritingEnabledProvider);
    if (!calendarWritingEnabled) return;

    final calendarController = CalendarController.instance;

    // Check if we should sync based on cooldown
    if (!calendarController.canSync()) return;

    // Get all RSVPs for the current user
    final rsvps = await ref.read(rsvpsProvider.future);
    if (rsvps.isEmpty) return;

    // Perform the full sync
    await calendarController.performFullSync(
      instances: instances,
      rsvps: rsvps,
    );
  }

  Future<Instance> patch(InstanceID id, Map<String, dynamic> patchData) async {
    logger.i({'instance:patch': patchData});

    try {
      final updatedData = await ref
          .read(supabaseClientProvider)
          .from('instances')
          .update(patchData)
          .eq('id', id)
          .select()
          .single();

      final updatedInstance = (await hydrate([updatedData])).first;

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
