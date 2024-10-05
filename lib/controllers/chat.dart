import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/logger.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/models/event_message.dart';
import 'package:squadquest/models/instance.dart';

final chatProvider =
    AsyncNotifierProviderFamily<ChatController, List<EventMessage>, InstanceID>(
        ChatController.new);

final latestChatProvider = AutoDisposeAsyncNotifierProviderFamily<
    LatestChatController, EventMessage, InstanceID>(LatestChatController.new);

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
    String content,
  ) async {
    final messageData = await ref
        .read(supabaseClientProvider)
        .from('event_messages')
        .insert({'instance': instanceId, 'content': content})
        .select()
        .single();

    final message = (await hydrate([messageData])).first;

    // update loaded rsvps with created/updated one
    if (state.hasValue && state.value != null) {
      state = AsyncValue.data(updateListWithRecord<EventMessage>(
          state.value!, (existing) => existing.id == message.id, message,
          prepend: true));
    }

    return message;
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
