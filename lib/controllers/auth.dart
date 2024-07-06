import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    final supabase = ref.read(supabaseClientProvider);

    // ref.listen(supabaseAuthStateChangesProvider, (previous, state) {
    //   log('AuthController.build.authStateChange: state: ${state.value?.event}, previous: ${previous?.value?.event}');
    // });

    return supabase.auth.currentSession;
  }

  void onAuthenticated(Function(Session) callback) {
    _onAuthenticatedCallbacks.add(callback);

    if (state != null) {
      callback(state!);
    }
  }

  bool _isTestPhone(String phone) {
    final String? testNumber = dotenv.maybeGet('TEST_PHONE');
    return testNumber != null && phone == testNumber;
  }

  Future<void> signInWithOtp({required String phone}) async {
    _verifyingPhone = phone;

    if (_isTestPhone(phone)) {
      log('Test phone number detected, skipping OTP SMS');
      return;
    }

    final supabase = ref.read(supabaseClientProvider);

    await supabase.auth.signInWithOtp(phone: phone);
  }

  Future<void> verifyOTP({required String token}) async {
    final supabase = ref.read(supabaseClientProvider);

    AuthResponse response;

    if (_isTestPhone(_verifyingPhone!)) {
      log('Test phone number detected, using password auth');
      response = await supabase.auth.signInWithPassword(
        phone: _verifyingPhone,
        password: token,
      );
    } else {
      response = await supabase.auth.verifyOTP(
        type: OtpType.sms,
        phone: _verifyingPhone,
        token: token,
      );
    }

    state = response.session;

    log('AuthController.verifyOTP: _onAuthenticatedCallbacks: ${_onAuthenticatedCallbacks.length}');
    for (final callback in _onAuthenticatedCallbacks) {
      callback(response.session!);
    }
  }

  Future<void> updateUserAttributes(Map<String, Object> data) async {
    final supabase = ref.read(supabaseClientProvider);

    await supabase.auth.updateUser(
      UserAttributes(
        data: data,
      ),
    );
  }

  Future<void> signOut() async {
    await ref.read(supabaseClientProvider).auth.signOut();
    state = null;
  }
}
