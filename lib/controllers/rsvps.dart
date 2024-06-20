import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';

final rsvpsProvider =
    AsyncNotifierProvider<RsvpsController, List<InstanceMember>>(
        RsvpsController.new);

final rsvpsPerEventProvider = AutoDisposeAsyncNotifierProviderFamily<
    InstanceRsvpsController,
    List<InstanceMember>,
    InstanceID>(InstanceRsvpsController.new);

class RsvpsController extends AsyncNotifier<List<InstanceMember>> {
  @override
  Future<List<InstanceMember>> build() async {
    final supabase = ref.read(supabaseClientProvider);
    final profilesCache = ref.read(profilesCacheProvider.notifier);

    // subscribe to changes
    supabase
        .from('instance_members')
        .stream(primaryKey: ['id'])
        .eq('member', supabase.auth.currentUser!.id)
        .listen((data) async {
          final populatedData = await profilesCache
              .populateData(data, [(idKey: 'member', modelKey: 'member')]);
          state = AsyncValue.data(
              populatedData.map(InstanceMember.fromMap).toList());
        });

    return future;
  }

  Future<InstanceMember?> save(
      InstanceID instanceId, InstanceMemberStatus? status) async {
    final supabase = ref.read(supabaseClientProvider);

    try {
      final response = await supabase.functions.invoke('rsvp',
          body: {'instance_id': instanceId, 'status': status?.name});

      final instanceMember = response.data['status'] == null
          ? null
          : InstanceMember.fromMap(response.data);

      // update loaded rsvps with created/updated one
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data(updateListWithRecord<InstanceMember>(
            state.value!,
            (existing) =>
                existing.instanceId == instanceId &&
                existing.memberId == supabase.auth.currentUser!.id,
            instanceMember));
      }

      return instanceMember;
    } on FunctionException catch (error) {
      throw error.details.toString().replaceAll(RegExp(r'^[a-z\-]+: '), '');
    }
  }

  Future<List<InstanceMember>> invite(
      InstanceID instanceId, List<UserID> userIds) async {
    final supabase = ref.read(supabaseClientProvider);

    try {
      final response = await supabase.functions.invoke('invite',
          body: {'instance_id': instanceId, 'users': userIds});

      return List<InstanceMember>.from(response.data
          .map((invitationData) => InstanceMember.fromMap(invitationData)));
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
    final profilesCache = ref.read(profilesCacheProvider.notifier);

    final populatedData = await profilesCache
        .populateData(data, [(idKey: 'member', modelKey: 'member')]);
    state = AsyncValue.data(populatedData.map(InstanceMember.fromMap).toList());
  }

  Future<InstanceMember?> save(InstanceMemberStatus? status) async {
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

    return savedRsvp;
  }
}
