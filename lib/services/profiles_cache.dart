import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/models/user.dart';

typedef ProfilesCache = Map<UserID, UserProfile>;

final profilesCacheProvider =
    NotifierProvider<ProfilesCacheService, ProfilesCache>(
        ProfilesCacheService.new);

class ProfilesCacheService extends Notifier<ProfilesCache> {
  final Completer<void> _initializedCompleter = Completer();
  Future get initialized => _initializedCompleter.future;

  @override
  ProfilesCache build() {
    // load profiles of friends network
    loadNetwork().then((_) {
      _initializedCompleter.complete();
    });

    return {};
  }

  Future<void> loadNetwork() async {
    final supabase = ref.read(supabaseClientProvider);

    try {
      final response = await supabase.functions
          .invoke('get-friends-network', method: HttpMethod.get);

      for (final profile in response.data) {
        state[profile['id']] = UserProfile.fromMap(profile);
      }

      // load own profile if needed
      final myUserId = supabase.auth.currentUser?.id;
      if (myUserId != null && !state.containsKey(myUserId)) {
        final myProfile = await ref.read(profileProvider.future);

        if (myProfile != null) {
          state[myUserId] = myProfile;
        }
      }
    } catch (error, stackTrace) {
      logger.e('Failed to load friends network',
          error: error, stackTrace: stackTrace);
    }
  }

  Future<void> cacheProfiles(List<UserProfile> profiles) async {
    for (UserProfile profile in profiles) {
      state[profile.id] = profile;
    }
  }

  Future<List<Map<String, dynamic>>> populateData(
      List<Map<String, dynamic>> data,
      List<({String idKey, String modelKey})> fields) async {
    // wait until cache is initialized with detailed friends data
    await initialized;

    // build set of missing IDs
    final Set<UserID> missingIds = {};
    for (final item in data) {
      for (final field in fields) {
        if (item[field.modelKey] is UserProfile) {
          continue;
        } else if (item[field.idKey] is Map &&
            item[field.idKey]['id'] != null) {
          item[field.idKey] = item[field.idKey]['id'];
        }

        final UserID userId = item[field.idKey];
        if (!state.containsKey(userId)) {
          missingIds.add(userId);
        }
      }
    }

    // fetch missing profiles into cache
    if (missingIds.isNotEmpty) {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('profiles_anonymous')
          .select('*')
          .inFilter('id', missingIds.toList())
          .withConverter((data) => data.map(UserProfile.fromMap).toList())
          .then(cacheProfiles);
    }

    // return hydrated data
    return data.map((Map<String, dynamic> item) {
      for (final field in fields) {
        if (item[field.modelKey] is UserProfile) {
          continue;
        }

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

  Future<Map<UserID, UserProfile>> fetchProfiles(Set<UserID> userIds) async {
    // wait until cache is initialized with detailed friends data
    await initialized;

    final result = <UserID, UserProfile>{};
    final missingIds = userIds.where((userId) => !state.containsKey(userId));

    // fetch missing profiles into cache
    if (missingIds.isNotEmpty) {
      final profiles = await ref
          .read(supabaseClientProvider)
          .from('profiles_anonymous')
          .select('*')
          .inFilter('id', missingIds.toList())
          .withConverter((data) => data.map(UserProfile.fromMap).toList());

      // add profiles to cache
      await cacheProfiles(profiles);
    }

    // add profiles to result
    for (final userId in userIds) {
      result[userId] = state[userId]!;
    }

    return result;
  }

  Future<UserProfile> getById(UserID userId) async {
    if (!state.containsKey(userId)) {
      await fetchProfiles({userId});
    }

    return state[userId]!;
  }
}
