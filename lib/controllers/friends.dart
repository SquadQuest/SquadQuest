import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/models/friend.dart';

final friendsProvider = AsyncNotifierProvider<FriendsController, List<Friend>>(
    FriendsController.new);

class FriendsController extends AsyncNotifier<List<Friend>> {
  @override
  Future<List<Friend>> build() async {
    final supabase = ref.read(supabaseClientProvider);

    // subscribe to changes
    supabase.from('friends').stream(primaryKey: ['id']).listen((data) async {
      state = AsyncValue.data(await hydrate(data));
    });

    return future;
  }

  Future<List<Friend>> fetch() async {
    final supabase = ref.read(supabaseClientProvider);

    final data = await supabase.from('friends').select();

    return hydrate(data);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(fetch);
  }

  Future<List<Friend>> hydrate(List<Map<String, dynamic>> data) async {
    final profilesCache = ref.read(profilesCacheProvider.notifier);

    // populate profile data
    await profilesCache.populateData(data, [
      (idKey: 'requester', modelKey: 'requester'),
      (idKey: 'requestee', modelKey: 'requestee')
    ]);

    return data.map(Friend.fromMap).toList();
  }

  Future<Friend?> sendFriendRequest(String phone, [Map? extra]) async {
    final supabase = ref.read(supabaseClientProvider);

    try {
      final response = await supabase.functions.invoke('send-friend-request',
          body: {'phone': normalizePhone(phone), ...extra ?? {}});

      if (response.data['invited'] == true) {
        return null;
      }

      final insertedFriend = (await hydrate([response.data])).first;

      // update loaded friends with newly created one
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data(updateListWithRecord<Friend>(
            state.value!,
            (existing) =>
                (existing.requesterId == insertedFriend.requesterId &&
                    existing.requesteeId == insertedFriend.requesteeId) ||
                (existing.requesterId == insertedFriend.requesteeId &&
                    existing.requesteeId == insertedFriend.requesterId),
            insertedFriend));
      }

      // return insertedFriend;
      return insertedFriend;
    } on FunctionException catch (error) {
      throw error.details.toString().replaceAll(RegExp(r'^[a-z\-]+: '), '');
    }
  }

  Future<Friend> respondToFriendRequest(
      Friend friend, FriendStatus action) async {
    final supabase = ref.read(supabaseClientProvider);

    try {
      final response = await supabase.functions.invoke('action-friend-request',
          body: {'friend_id': friend.id, 'action': action.name});

      final insertedFriend = (await hydrate([response.data])).first;

      // update loaded friends with created/updated one
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data(updateListWithRecord<Friend>(
            state.value!,
            (existing) =>
                (existing.requesterId == insertedFriend.requesterId &&
                    existing.requesteeId == insertedFriend.requesteeId) ||
                (existing.requesterId == insertedFriend.requesteeId &&
                    existing.requesteeId == insertedFriend.requesterId),
            insertedFriend));
      }

      // return insertedFriend;
      return insertedFriend;
    } on FunctionException catch (error) {
      throw error.details.toString().replaceAll(RegExp(r'^[a-z\-]+: '), '');
    }
  }
}
