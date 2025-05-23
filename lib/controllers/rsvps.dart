import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/calendar.dart';
import 'package:squadquest/controllers/settings.dart';
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

final myRsvpPerEventProvider = FutureProvider.autoDispose
    .family<InstanceMember?, InstanceID>((ref, eventId) async {
  final session = ref.watch(authControllerProvider);

  if (session == null) {
    return null;
  }

  final eventRsvps = await ref.watch(rsvpsPerEventProvider(eventId).future);

  return eventRsvps
      .firstWhereOrNull((rsvp) => rsvp.memberId == session.user.id);
});

class RsvpsController extends AsyncNotifier<List<InstanceMember>> {
  @override
  FutureOr<List<InstanceMember>> build() async {
    log('RsvpsController.fetch');

    final supabase = ref.read(supabaseClientProvider);

    // ensure a session is available
    if (supabase.auth.currentUser == null) {
      return [];
    }

    // subscribe to changes
    final subscription = supabase
        .from('instance_members')
        .stream(primaryKey: ['id'])
        .eq('member', supabase.auth.currentUser!.id)
        .listen((data) async {
          state = AsyncValue.data(await hydrate(data));
        });

    // cancel subscription when provider is disposed
    ref.onDispose(() {
      subscription.cancel();
    });

    return future;
  }

  Future<List<InstanceMember>> hydrate(List<Map<String, dynamic>> data) async {
    final profilesCache = ref.read(profilesCacheProvider.notifier);

    // populate profile data
    await profilesCache
        .populateData(data, [(idKey: 'member', modelKey: 'member')]);

    return data.map(InstanceMember.fromMap).toList();
  }

  Future<InstanceMember?> save(Instance instance, InstanceMemberStatus? status,
      {String? note}) async {
    final supabase = ref.read(supabaseClientProvider);

    try {
      final response = await supabase.functions.invoke('rsvp', body: {
        'instance_id': instance.id,
        'status': status?.name,
        if (note != null) 'note': note,
      });

      final instanceMember = response.data['status'] == null
          ? null
          : (await hydrate([response.data])).first;

      // update loaded rsvps with created/updated one
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data(
          updateListWithRecord<InstanceMember>(
            state.value!,
            (existing) =>
                existing.instanceId == instance.id &&
                existing.memberId == supabase.auth.currentUser!.id,
            instanceMember,
          ),
        );
      }

      // Handle calendar sync
      if (ref.read(calendarWritingEnabledProvider)) {
        if (instanceMember != null &&
            instanceMember.status != InstanceMemberStatus.no) {
          await CalendarController.instance.upsertEvent(
            subscription: instanceMember,
            instance: instance,
          );
        } else {
          await CalendarController.instance.deleteEvent(instance);
        }
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

      return hydrate(response.data.cast<Map<String, dynamic>>());
    } on FunctionException catch (error) {
      throw error.details.toString().replaceAll(RegExp(r'^[a-z\-]+: '), '');
    }
  }
}

class InstanceRsvpsController
    extends AutoDisposeFamilyAsyncNotifier<List<InstanceMember>, InstanceID> {
  late InstanceID instanceId;

  InstanceRsvpsController();

  @override
  Future<List<InstanceMember>> build(InstanceID arg) async {
    instanceId = arg;

    // subscribe to changes
    final subscription = ref
        .read(supabaseClientProvider)
        .from('instance_members')
        .stream(primaryKey: ['id'])
        .eq('instance', instanceId)
        .listen(_onData);

    // cancel subscription when provider is disposed
    ref.onDispose(() {
      subscription.cancel();
    });

    return future;
  }

  void _onData(List<Map<String, dynamic>> data) async {
    final rsvpsController = ref.read(rsvpsProvider.notifier);
    state = AsyncValue.data(await rsvpsController.hydrate(data));
  }
}
