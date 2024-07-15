import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/models/user.dart';

final profileProvider = AsyncNotifierProvider<ProfileController, UserProfile?>(
    ProfileController.new);

class ProfileController extends AsyncNotifier<UserProfile?> {
  static const _defaultSelect = '*';

  @override
  Future<UserProfile?> build() async {
    log('ProfileController.build');

    // clear profile on logout
    ref.listen(authControllerProvider, (previous, session) {
      log('ProfileController.build.authChange: session: ${session == null ? 'no' : 'yes'}, previous: ${previous == null ? 'no' : 'yes'}');
      if (session == null) {
        state = const AsyncValue.data(null);
      }
    });

    return fetch();
  }

  Future<UserProfile?> fetch() async {
    final supabase = ref.read(supabaseClientProvider);
    final session = ref.read(authControllerProvider);
    log('ProfileController.fetch: session: ${session == null ? 'no' : 'yes'}');

    if (session == null) {
      logger.t('ProfileController.fetch: no session');
      return null;
    }

    state = const AsyncValue.loading();

    logger.t('ProfileController.fetch: loading');
    final profiles = await supabase
        .from('profiles')
        .select(_defaultSelect)
        .eq('id', session.user.id)
        .withConverter((data) => data.map(UserProfile.fromMap).toList());
    logger.t({'ProfileController.fetch: loaded': profiles});

    final profile = profiles.isNotEmpty ? profiles.first : null;
    state = AsyncValue.data(profile);
    logger.t({'ProfileController.fetch: set state': profile});

    return profile;
  }

  Future<UserProfile> save(UserProfile profile) async {
    logger.i({'profile:save': profile});

    assert(profile.id.isNotEmpty, 'Cannot save a profile with no ID');

    final supabase = ref.read(supabaseClientProvider);

    final Map profileData = profile.toMap();

    final insertedData = await supabase
        .from('profiles')
        .upsert(profileData)
        .select(_defaultSelect);

    final insertedProfile = UserProfile.fromMap(insertedData.first);

    state = AsyncValue.data(insertedProfile);

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
}
