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
}
