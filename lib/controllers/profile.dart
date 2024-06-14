import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/models/user.dart';

final profileProvider = AsyncNotifierProvider<ProfileController, UserProfile?>(
    ProfileController.new);

class ProfileController extends AsyncNotifier<UserProfile?> {
  static const _defaultSelect = '*';

  @override
  Future<UserProfile?> build() async {
    return fetch();
  }

  Future<UserProfile?> fetch() async {
    final supabase = ref.read(supabaseProvider);
    final authController = await ref.read(authControllerProvider.future);

    final profiles = await supabase
        .from('profiles')
        .select(_defaultSelect)
        .eq('id', authController!.user.id)
        .withConverter((data) => data.map(UserProfile.fromMap).toList());
    final profile = profiles.isNotEmpty ? profiles.first : null;
    state = AsyncValue.data(profile);

    return profile;
  }

  Future<UserProfile> save(UserProfile profile) async {
    assert(profile.id.isNotEmpty, 'Cannot save a profile with no ID');

    final supabase = ref.read(supabaseProvider);

    final Map profileData = profile.toMap();

    final insertedData = await supabase
        .from('profiles')
        .upsert(profileData)
        .select(_defaultSelect);

    final insertedProfile = UserProfile.fromMap(insertedData.first);

    state = AsyncValue.data(insertedProfile);

    return insertedProfile;
  }
}
