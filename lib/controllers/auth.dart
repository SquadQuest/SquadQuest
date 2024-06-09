import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/services/supabase.dart';

export 'package:squad_quest/services/supabase.dart' show Session, User;

final authControllerProvider =
    AsyncNotifierProvider<AuthController, Session?>(AuthController.new);

final userProvider = StateProvider<User?>((ref) {
  final authController = ref.watch(authControllerProvider);
  return authController.value?.user;
});

class AuthController extends AsyncNotifier<Session?> {
  AuthController();

  @override
  Session? build() {
    final supabase = ref.read(supabaseProvider);

    return supabase.auth.currentSession;
  }

  Future<void> signInWithOtp({required String phone}) async {
    state = const AsyncValue.loading();

    final supabase = ref.read(supabaseProvider);

    await supabase.auth.signInWithOtp(phone: phone);
  }

  Future<void> verifyOTP({required String phone, required String token}) async {
    state = const AsyncValue.loading();

    final supabase = ref.read(supabaseProvider);

    final AuthResponse response = await supabase.auth.verifyOTP(
      type: OtpType.sms,
      phone: phone,
      token: token,
    );

    state = AsyncValue.data(response.session);
  }
}
