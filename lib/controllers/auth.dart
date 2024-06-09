import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/services/supabase.dart';

export 'package:squad_quest/services/supabase.dart' show Session, User;

final authControllerProvider = Provider<AuthController>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AuthController(supabase);
});

class AuthController {
  AuthController(this.supabase);
  final SupabaseClient supabase;
  Session? session;
  User? user;

  Future<void> signInWithOtp({required String phone}) async {
    await supabase.auth.signInWithOtp(phone: phone);
  }

  Future<void> verifyOTP({required String phone, required String token}) async {
    final AuthResponse response = await supabase.auth.verifyOTP(
      type: OtpType.sms,
      phone: phone,
      token: token,
    );

    session = response.session;
    user = response.user;
  }
}
