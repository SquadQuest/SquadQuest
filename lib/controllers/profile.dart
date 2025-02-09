import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/models/user.dart';

final profileProvider = AsyncNotifierProvider<ProfileController, UserProfile?>(
    ProfileController.new);

class ProfileController extends AsyncNotifier<UserProfile?> {
  static const _defaultSelect = '*';

  @override
  FutureOr<UserProfile?> build() async {
    log('ProfileController.build');

    // clear profile on logout
    ref.listen(authControllerProvider, (previous, session) {
      log('ProfileController.build.authChange: session: ${session == null ? 'no' : 'yes'}, previous: ${previous == null ? 'no' : 'yes'}');
      if (session == null) {
        state = const AsyncValue.data(null);
      }
    });

    return fetch(throwOnError: true);
  }

  Future<UserProfile?> fetch({bool throwOnError = false}) async {
    final supabase = ref.read(supabaseClientProvider);
    final session = ref.read(authControllerProvider);
    log('ProfileController.fetch: session: ${session == null ? 'no' : 'yes'}');

    if (session == null) {
      logger.t('ProfileController.fetch: no session');
      return null;
    }

    state = const AsyncValue.loading();

    try {
      logger.t('ProfileController.fetch: loading');
      final data = await supabase
          .from('profiles')
          .select(_defaultSelect)
          .eq('id', session.user.id);

      final profiles = await hydrate(data);
      logger.t({'ProfileController.fetch: loaded': profiles});

      final profile = profiles.isNotEmpty ? profiles.first : null;
      state = AsyncValue.data(profile);
      logger.t({'ProfileController.fetch: set state': profile});

      return profile;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);

      if (throwOnError) {
        rethrow;
      }

      return null;
    }
  }

  Future<List<UserProfile>> hydrate(List<Map<String, dynamic>> data) async {
    return data.map(UserProfile.fromMap).toList();
  }

  Future<UserProfile> save(UserProfile profile) async {
    logger.i({'profile:save': profile});

    assert(profile.id.isNotEmpty, 'Cannot save a profile with no ID');

    final supabase = ref.read(supabaseClientProvider);

    final Map profileData = profile.toMap();

    final insertedData = await supabase
        .from('profiles')
        .upsert(profileData)
        .select(_defaultSelect)
        .single();

    final insertedProfile = (await hydrate([insertedData])).first;

    state = AsyncValue.data(insertedProfile);

    // update profile cache
    ref.read(profilesCacheProvider.notifier).cacheProfiles([insertedProfile]);

    return insertedProfile;
  }

  Future<UserProfile> patch(Map<String, dynamic> patchData) async {
    logger.i({'profile:patch': patchData});

    final currentProfile = state.value;

    late UserProfile patchedProfile;
    if (currentProfile == null) {
      patchedProfile = UserProfile.fromMap(patchData);
    } else {
      final patchedProfileData = currentProfile.toMap();
      patchedProfileData.addAll(patchData);
      patchedProfile = UserProfile.fromMap(patchedProfileData);
    }

    return save(patchedProfile);
  }

  Future<void> setNotificationEnabled(
      NotificationType type, bool enabled) async {
    final enabledNotifications = state.value!.enabledNotifications;

    if (enabled) {
      enabledNotifications.add(type);
    } else {
      enabledNotifications.remove(type);
    }

    final enabledNotificationsFull =
        enabledNotifications.map((type) => type.name).toList().cast<String>();

    enabledNotificationsFull.addAll(state.value!.unparsedNotifications);

    try {
      final updatedData = await ref
          .read(supabaseClientProvider)
          .from('profiles')
          .update({'enabled_notifications_v2': enabledNotificationsFull})
          .eq('id', state.value!.id)
          .select()
          .single();

      final updatedProfile = (await hydrate([updatedData])).first;

      state = AsyncValue.data(updatedProfile);
    } catch (error) {
      loggerWithStack.e({'error patching enabled_notifications_v2': error});
      rethrow;
    }
  }
}
