import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/services/supabase.dart';
import 'package:squad_quest/services/profiles_cache.dart';
import 'package:squad_quest/models/instance.dart';
import 'package:squad_quest/models/user.dart';

final rsvpsProvider =
    AsyncNotifierProvider<RsvpsController, List<InstanceMember>>(
        RsvpsController.new);

class RsvpsController extends AsyncNotifier<List<InstanceMember>> {
  @override
  Future<List<InstanceMember>> build() async {
    final profilesCache = ref.read(profilesCacheProvider.notifier);

    // subscribe to changes
    final supabase = ref.read(supabaseProvider);
    supabase
        .from('instance_members')
        .stream(primaryKey: ['id'])
        .eq('member', supabase.auth.currentUser!.id)
        .listen((data) async {
          final populatedData = await profilesCache.populateData(data);
          state = AsyncValue.data(
              populatedData.map(InstanceMember.fromMap).toList());
        });

    return future;
  }

  void subscribeByInstance(
      InstanceID instanceId, Function(List<InstanceMember>) onData) async {
    final supabase = ref.read(supabaseProvider);
    final profilesCache = ref.read(profilesCacheProvider.notifier);

    supabase
        .from('instance_members')
        .stream(primaryKey: ['id'])
        .eq('instance', instanceId)
        .listen((data) async {
          final populatedData = await profilesCache.populateData(data);
          onData(populatedData.map(InstanceMember.fromMap).toList());
        });
  }

  Future<InstanceMember?> save(
      Instance instance, InstanceMemberStatus? status) async {
    final List<InstanceMember>? loadedRsvps =
        state.hasValue ? state.asData!.value : null;

    final supabase = ref.read(supabaseProvider);

    try {
      final response = await supabase.functions.invoke('rsvp',
          body: {'instance_id': instance.id, 'status': status?.name});

      final instanceMember = response.data['status'] == null
          ? null
          : InstanceMember.fromMap(response.data);

      // update loaded friends with created/updated one
      if (loadedRsvps != null) {
        final index = instanceMember != null
            ? loadedRsvps.indexWhere((f) => f.id == instanceMember.id)
            : loadedRsvps.indexWhere((f) =>
                f.instanceId == instance.id &&
                f.memberId == supabase.auth.currentUser!.id);

        late List<InstanceMember> updatedList;
        if (index == -1) {
          // append a new rsvp
          updatedList = [
            ...loadedRsvps,
            instanceMember!,
          ];
        } else if (instanceMember == null) {
          // remove existing rsvp
          updatedList = [
            ...loadedRsvps.sublist(0, index),
            ...loadedRsvps.sublist(index + 1)
          ];
        } else {
          // replace existing rsvp
          updatedList = [
            ...loadedRsvps.sublist(0, index),
            instanceMember,
            ...loadedRsvps.sublist(index + 1)
          ];
        }

        state = AsyncValue.data(updatedList);
      }

      return instanceMember;
    } on FunctionException catch (error) {
      throw error.details.toString().replaceAll(RegExp(r'^[a-z\-]+: '), '');
    }
  }

  Future<List<InstanceMember>> invite(
      Instance instance, List<UserID> userIds) async {
    final supabase = ref.read(supabaseProvider);

    try {
      final response = await supabase.functions.invoke('invite',
          body: {'instance_id': instance.id, 'users': userIds});

      return List<InstanceMember>.from(response.data
          .map((invitationData) => InstanceMember.fromMap(invitationData)));
    } on FunctionException catch (error) {
      throw error.details.toString().replaceAll(RegExp(r'^[a-z\-]+: '), '');
    }
  }
}
