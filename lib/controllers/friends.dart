import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/models/friend.dart';

final friendsProvider = AsyncNotifierProvider<FriendsController, List<Friend>>(
    FriendsController.new);

class FriendsController extends AsyncNotifier<List<Friend>> {
  static const _defaultSelect = '*, requester(*), requestee(*)';

  @override
  Future<List<Friend>> build() async {
    final supabase = ref.read(supabaseClientProvider);
    final profilesCache = ref.read(profilesCacheProvider.notifier);

    // subscribe to changes
    supabase.from('friends').stream(primaryKey: ['id']).listen((data) async {
      final populatedData = await profilesCache.populateData(data, [
        (idKey: 'requester', modelKey: 'requester'),
        (idKey: 'requestee', modelKey: 'requestee')
      ]);
      state = AsyncValue.data(populatedData.map(Friend.fromMap).toList());
    });

    return future;
  }

  Future<List<Friend>> fetch() async {
    final supabase = ref.read(supabaseClientProvider);

    return supabase
        .from('friends')
        .select(_defaultSelect)
        .withConverter((data) => data.map(Friend.fromMap).toList());
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(fetch);
  }

  Future<Friend> sendFriendRequest(String phone) async {
    final supabase = ref.read(supabaseClientProvider);

    try {
      final response = await supabase.functions
          .invoke('send-friend-request', body: {'phone': phone});

      final insertedFriend = Friend.fromMap(response.data);

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

      final insertedFriend = Friend.fromMap(response.data);

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
