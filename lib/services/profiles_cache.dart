import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/models/user.dart';

typedef ProfilesCache = Map<UserID, UserProfile>;

final profilesCacheProvider =
    NotifierProvider<ProfilesCacheService, ProfilesCache>(
        ProfilesCacheService.new);

class ProfilesCacheService extends Notifier<ProfilesCache> {
  @override
  ProfilesCache build() {
    return {};
  }

  Future<void> cacheProfiles(List<UserProfile> profiles) async {
    for (UserProfile profile in profiles) {
      state[profile.id] = profile;
    }
  }

  Future<List<Map<String, dynamic>>> populateData(
      List<Map<String, dynamic>> data,
      {String idKey = 'member',
      String modelKey = 'member'}) async {
    // fetch missing profiles
    final List<UserID> missingIds = data
        .map((Map item) => item[idKey])
        .whereType<UserID>()
        .where((UserID id) => !state.containsKey(id))
        .toSet()
        .toList();

    if (missingIds.isNotEmpty) {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('profiles')
          .select('*')
          .inFilter('id', missingIds)
          .withConverter((data) => data.map(UserProfile.fromMap).toList())
          .then(cacheProfiles);
    }

    // return hydrated data
    return data.map((Map<String, dynamic> item) {
      if (item.containsKey(idKey) && item[idKey] is UserID) {
        final UserProfile? profile = state[item[idKey]];
        if (profile != null) {
          item[modelKey] = profile;
        }
      }
      return item;
    }).toList();
  }
}
