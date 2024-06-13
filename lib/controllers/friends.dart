import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/services/supabase.dart';
import 'package:squad_quest/models/friend.dart';

final friendsProvider = AsyncNotifierProvider<FriendsController, List<Friend>>(
    FriendsController.new);

class FriendsController extends AsyncNotifier<List<Friend>> {
  static const _defaultSelect = '*, requester(*), requestee(*)';

  @override
  Future<List<Friend>> build() async {
    return fetch();
  }

  Future<List<Friend>> fetch() async {
    final supabase = ref.read(supabaseProvider);

    return supabase
        .from('friends')
        .select(_defaultSelect)
        .withConverter((data) => data.map(Friend.fromMap).toList());
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(fetch);
  }

  Future<Friend> sendFriendRequest(String phone) async {
    final List<Friend>? loadedFriends =
        state.hasValue ? state.asData!.value : null;

    final supabase = ref.read(supabaseProvider);

    try {
      final response = await supabase.functions
          .invoke('send-friend-request', body: {'phone': phone});

      final insertedFriend = Friend.fromMap(response.data);

      // update loaded friends with newly created one
      if (loadedFriends != null) {
        List<Friend> updatedList = [...loadedFriends, insertedFriend];
        state = AsyncValue.data(updatedList);
      }

      // return insertedFriend;
      return insertedFriend;
    } on FunctionException catch (error) {
      throw error.details.toString().replaceAll(RegExp(r'^[a-z\-]+: '), '');
    }
  }

  Future<Friend> respondToFriendRequest(
      Friend friend, FriendStatus action) async {
    final List<Friend>? loadedFriends =
        state.hasValue ? state.asData!.value : null;

    final supabase = ref.read(supabaseProvider);

    try {
      final response = await supabase.functions.invoke('action-friend-request',
          body: {'friend_id': friend.id, 'action': action.name});

      final insertedFriend = Friend.fromMap(response.data);

      // update loaded friends with newly created one
      if (loadedFriends != null) {
        final index = loadedFriends.indexWhere((f) => f.id == friend.id);

        if (index != -1) {
          List<Friend> updatedList = [
            ...loadedFriends.sublist(0, index),
            insertedFriend,
            ...loadedFriends.sublist(index + 1)
          ];
          state = AsyncValue.data(updatedList);
        }
      }

      // return insertedFriend;
      return insertedFriend;
    } on FunctionException catch (error) {
      throw error.details.toString().replaceAll(RegExp(r'^[a-z\-]+: '), '');
    }
  }
}
