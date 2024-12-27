import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/logger.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/models/event_message.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/auth.dart';

final chatProvider =
    AsyncNotifierProviderFamily<ChatController, List<EventMessage>, InstanceID>(
        ChatController.new);

final latestChatProvider = AutoDisposeAsyncNotifierProviderFamily<
    LatestChatController, EventMessage, InstanceID>(LatestChatController.new);

final latestPinnedMessageProvider = AutoDisposeAsyncNotifierProviderFamily<
    LatestPinnedMessageController, EventMessage?, InstanceID>(
  LatestPinnedMessageController.new,
);

final chatMessageCountProvider =
    FutureProvider.autoDispose.family<int?, InstanceID>((ref, eventId) async {
  final myRsvp = await ref.watch(myRsvpPerEventProvider(eventId).future);

  // Count messages after last seen
  final result = await ref
      .read(supabaseClientProvider)
      .from('event_messages')
      .select('id')
      .eq('instance', eventId)
      .gt('created_at',
          (myRsvp?.chatLastSeen ?? DateTime(0)).toUtc().toIso8601String())
      .count(CountOption.exact);

  return result.count;
});

class ChatController
    extends FamilyAsyncNotifier<List<EventMessage>, InstanceID> {
  late InstanceID instanceId;
  late StreamSubscription _subscription;

  ChatController();

  @override
  Future<List<EventMessage>> build(InstanceID arg) async {
    instanceId = arg;

    // subscribe to changes
    _subscription = ref
        .read(supabaseClientProvider)
        .from('event_messages')
        .stream(primaryKey: ['id'])
        .eq('instance', instanceId)
        .order('created_at', ascending: false)
        .listen(_onData);

    // cancel subscription when provider is disposed
    ref.onDispose(() {
      _subscription.cancel();
    });

    return future;
  }

  Future<List<EventMessage>> hydrate(List<Map<String, dynamic>> data) async {
    final profilesCache = ref.read(profilesCacheProvider.notifier);

    // populate profile data
    await profilesCache
        .populateData(data, [(idKey: 'created_by', modelKey: 'created_by')]);

    return data.map(EventMessage.fromMap).toList();
  }

  void _onData(List<Map<String, dynamic>> data) async {
    try {
      state = AsyncValue.data(await hydrate(data));
    } catch (error, stackTrace) {
      logger.e('Failed to hydrate chat messages',
          error: error, stackTrace: stackTrace);
    }
  }

  Future<EventMessage?> post(
    String content, {
    bool pinned = false,
  }) async {
    final messageData = await ref
        .read(supabaseClientProvider)
        .from('event_messages')
        .insert({
          'instance': instanceId,
          'content': content,
          'pinned': pinned,
        })
        .select()
        .single();

    final message = (await hydrate([messageData])).first;

    // update loaded rsvps with created/updated one
    if (state.hasValue && state.value != null) {
      state = AsyncValue.data(updateListWithRecord<EventMessage>(
          state.value!, (existing) => existing.id == message.id, message,
          prepend: true));
    }

    // invalidate count cache
    ref.invalidate(chatMessageCountProvider(instanceId));

    return message;
  }
}

class LatestPinnedMessageController
    extends AutoDisposeFamilyAsyncNotifier<EventMessage?, InstanceID> {
  @override
  Future<EventMessage?> build(InstanceID arg) async {
    // Watch latestChatProvider to get updates
    ref.listen(latestChatProvider(arg), (previous, next) {
      next.whenData((message) {
        // Update state if we receive a pinned message that's newer than our current one
        if (message.pinned &&
            (state.value == null ||
                message.createdAt.isAfter(state.value!.createdAt))) {
          state = AsyncValue.data(message);
        }
      });
    });

    // Get initial state by querying for latest pinned message
    final supabase = ref.read(supabaseClientProvider);
    final data = await supabase
        .from('event_messages')
        .select()
        .eq('instance', arg)
        .eq('pinned', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;

    final profilesCache = ref.read(profilesCacheProvider.notifier);
    await profilesCache
        .populateData([data], [(idKey: 'created_by', modelKey: 'created_by')]);

    return EventMessage.fromMap(data);
  }
}

class LatestChatController
    extends AutoDisposeFamilyAsyncNotifier<EventMessage, InstanceID> {
  late InstanceID instanceId;
  late StreamSubscription _subscription;

  LatestChatController();

  @override
  Future<EventMessage> build(InstanceID arg) async {
    instanceId = arg;

    // subscribe to changes
    _subscription = ref
        .read(supabaseClientProvider)
        .from('event_messages')
        .stream(primaryKey: ['id'])
        .eq('instance', instanceId)
        .order('created_at', ascending: false)
        .limit(1)
        .listen(_onData);

    // cancel subscription when provider is disposed
    ref.onDispose(() {
      _subscription.cancel();
    });

    return future;
  }

  Future<EventMessage> hydrate(Map<String, dynamic> data) async {
    final profilesCache = ref.read(profilesCacheProvider.notifier);

    // populate profile data
    await profilesCache
        .populateData([data], [(idKey: 'created_by', modelKey: 'created_by')]);

    return EventMessage.fromMap(data);
  }

  void _onData(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) {
      return;
    }

    try {
      state = AsyncValue.data(await hydrate(data.first));
    } catch (error, stackTrace) {
      logger.e('Failed to hydrate chat message',
          error: error, stackTrace: stackTrace);
    }
  }
}
