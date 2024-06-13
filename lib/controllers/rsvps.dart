import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/services/supabase.dart';
import 'package:squad_quest/models/instance.dart';

final rsvpsProvider =
    AsyncNotifierProvider<RsvpsController, List<InstanceMember>>(
        RsvpsController.new);

class RsvpsController extends AsyncNotifier<List<InstanceMember>> {
  static const _defaultSelect = '*, member(*)';

  @override
  Future<List<InstanceMember>> build() async {
    return fetchOwn();
  }

  Future<List<InstanceMember>> fetchOwn() async {
    final supabase = ref.read(supabaseProvider);

    return supabase
        .from('instance_members')
        .select(_defaultSelect)
        .eq('member', supabase.auth.currentUser!.id)
        .withConverter((data) => data.map(InstanceMember.fromMap).toList());
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(fetchOwn);
  }

  Future<List<InstanceMember>> fetchByInstance(InstanceID instanceId) async {
    final supabase = ref.read(supabaseProvider);

    return supabase
        .from('instance_members')
        .select(_defaultSelect)
        .eq('instance', instanceId)
        .withConverter((data) => data.map(InstanceMember.fromMap).toList());
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
}
