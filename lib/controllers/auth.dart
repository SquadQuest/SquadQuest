import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/supabase.dart';

export 'package:squadquest/services/supabase.dart' show Session, User;

final authControllerProvider =
    NotifierProvider<AuthController, Session?>(AuthController.new);

class AuthController extends Notifier<Session?> {
  final List<Function(Session)> _onAuthenticatedCallbacks = [];

  AuthController();

  String? _verifyingPhone;

  @override
  Session? build() {
    final supabase = ref.read(supabaseProvider);

    return supabase.auth.currentSession;
  }

  void onAuthenticated(Function(Session) callback) {
    _onAuthenticatedCallbacks.add(callback);

    if (state != null) {
      callback(state!);
    }
  }

  Future<void> signInWithOtp({required String phone}) async {
    _verifyingPhone = phone;

    final supabase = ref.read(supabaseProvider);

    await supabase.auth.signInWithOtp(phone: phone);
  }

  Future<void> verifyOTP({required String token}) async {
    final supabase = ref.read(supabaseProvider);

    final AuthResponse response = await supabase.auth.verifyOTP(
      type: OtpType.sms,
      phone: _verifyingPhone,
      token: token,
    );

    state = response.session;

    log('AuthController.verifyOTP: _onAuthenticatedCallbacks: ${_onAuthenticatedCallbacks.length}');
    for (final callback in _onAuthenticatedCallbacks) {
      callback(response.session!);
    }
  }

  Future<void> updateUserAttributes(Map<String, Object> data) async {
    final supabase = ref.read(supabaseProvider);

    await supabase.auth.updateUser(
      UserAttributes(
        data: data,
      ),
    );
  }

  Future<void> signOut() async {
    await ref.read(supabaseProvider).auth.signOut();
    state = null;
  }
}
