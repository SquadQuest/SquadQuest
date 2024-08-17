import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/controllers/calendar.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';

final rsvpsProvider =
    AsyncNotifierProvider<RsvpsController, List<InstanceMember>>(RsvpsController.new);

final rsvpsPerEventProvider = AutoDisposeAsyncNotifierProviderFamily<InstanceRsvpsController,
    List<InstanceMember>, InstanceID>(InstanceRsvpsController.new);

class RsvpsController extends AsyncNotifier<List<InstanceMember>> {
  @override
  Future<List<InstanceMember>> build() async {
    final supabase = ref.read(supabaseClientProvider);

    // subscribe to changes
    supabase
        .from('instance_members')
        .stream(primaryKey: ['id'])
        .eq('member', supabase.auth.currentUser!.id)
        .listen((data) async {
          state = AsyncValue.data(await hydrate(data));
        });

    return future;
  }

  Future<List<InstanceMember>> hydrate(List<Map<String, dynamic>> data) async {
    final profilesCache = ref.read(profilesCacheProvider.notifier);

    // populate profile data
    await profilesCache.populateData(data, [(idKey: 'member', modelKey: 'member')]);

    return data.map(InstanceMember.fromMap).toList();
  }

  Future<InstanceMember?> save(InstanceID instanceId, InstanceMemberStatus? status) async {
    final supabase = ref.read(supabaseClientProvider);

    try {
      final response = await supabase.functions
          .invoke('rsvp', body: {'instance_id': instanceId, 'status': status?.name});

      final instanceMember =
          response.data['status'] == null ? null : (await hydrate([response.data])).first;

      // update loaded rsvps with created/updated one
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data(
          updateListWithRecord<InstanceMember>(
            state.value!,
            (existing) =>
                existing.instanceId == instanceId &&
                existing.memberId == supabase.auth.currentUser!.id,
            instanceMember,
          ),
        );
      }

      return instanceMember;
    } on FunctionException catch (error) {
      throw error.details.toString().replaceAll(RegExp(r'^[a-z\-]+: '), '');
    }
  }

  Future<List<InstanceMember>> invite(InstanceID instanceId, List<UserID> userIds) async {
    final supabase = ref.read(supabaseClientProvider);

    try {
      final response = await supabase.functions
          .invoke('invite', body: {'instance_id': instanceId, 'users': userIds});

      return hydrate(response.data);
    } on FunctionException catch (error) {
      throw error.details.toString().replaceAll(RegExp(r'^[a-z\-]+: '), '');
    }
  }
}

class InstanceRsvpsController
    extends AutoDisposeFamilyAsyncNotifier<List<InstanceMember>, InstanceID> {
  late InstanceID instanceId;
  late StreamSubscription _subscription;

  InstanceRsvpsController();

  @override
  Future<List<InstanceMember>> build(InstanceID arg) async {
    instanceId = arg;

    // subscribe to changes
    _subscription = ref
        .read(supabaseClientProvider)
        .from('instance_members')
        .stream(primaryKey: ['id'])
        .eq('instance', instanceId)
        .listen(_onData);

    // cancel subscription when provider is disposed
    ref.onDispose(() {
      _subscription.cancel();
    });

    return future;
  }

  void _onData(List<Map<String, dynamic>> data) async {
    final rsvpsController = ref.read(rsvpsProvider.notifier);

    state = AsyncValue.data(await rsvpsController.hydrate(data));
  }

  Future<InstanceMember?> save(
    InstanceMemberStatus? status,
    Instance instance,
  ) async {
    final supabase = ref.read(supabaseClientProvider);
    final rsvpsController = ref.read(rsvpsProvider.notifier);

    final savedRsvp = await rsvpsController.save(instanceId, status);

    // update loaded rsvps with created/updated one
    if (state.hasValue && state.value != null) {
      state = AsyncValue.data(updateListWithRecord<InstanceMember>(
          state.value!,
          (existing) =>
              existing.instanceId == instanceId &&
              existing.memberId == supabase.auth.currentUser!.id,
          savedRsvp));
    }

    if (savedRsvp != null) {
      await CalendarController.instance.upsertEvent(
        subscription: savedRsvp,
        instance: instance,
      );
    } else {
      await CalendarController.instance.deleteEvent(instance);
    }

    return savedRsvp;
  }
}
