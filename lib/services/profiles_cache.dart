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
      List<({String idKey, String modelKey})> fields) async {
    // build set of missing IDs
    final Set<UserID> missingIds = {};
    for (final datum in data) {
      for (final field in fields) {
        final UserID userId = datum[field.idKey];
        if (!state.containsKey(userId)) {
          missingIds.add(userId);
        }
      }
    }

    // fetch missing profiles into cache
    if (missingIds.isNotEmpty) {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('profiles')
          .select('*')
          .inFilter('id', missingIds.toList())
          .withConverter((data) => data.map(UserProfile.fromMap).toList())
          .then(cacheProfiles);
    }

    // return hydrated data
    return data.map((Map<String, dynamic> item) {
      for (final field in fields) {
        if (item.containsKey(field.idKey) && item[field.idKey] is UserID) {
          final UserProfile? profile = state[item[field.idKey]];
          if (profile != null) {
            item[field.modelKey] = profile;
          }
        }
      }
      return item;
    }).toList();
  }
}
