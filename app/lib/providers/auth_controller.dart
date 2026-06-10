import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import 'providers.dart';

// ── Auth state ──────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

/// Resolving the persisted session at launch.
class AuthLoading extends AuthState {
  const AuthLoading();
}

class SignedOut extends AuthState {
  const SignedOut();
}

/// OTP requested for [phone]; awaiting the code.
class AwaitingOtp extends AuthState {
  const AwaitingOtp(this.phone);
  final String phone;
}

class SignedIn extends AuthState {
  const SignedIn(this.profile);
  final Profile profile;
}

// ── Controller ────────────────────────────────────────────────────────────────

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthLoading();
  }

  // On launch: load persisted tokens; if a session exists, fetch the profile.
  Future<void> _restore() async {
    final tokens = ref.read(tokenStoreProvider);
    await tokens.load();
    if (!tokens.hasSession) {
      state = const SignedOut();
      return;
    }
    try {
      state = SignedIn(await ref.read(profileRepositoryProvider).me());
    } catch (_) {
      await tokens.clear();
      state = const SignedOut();
    }
  }

  Future<void> requestOtp(String phone) async {
    await ref.read(authRepositoryProvider).requestOtp(phone);
    state = AwaitingOtp(phone);
  }

  Future<void> verifyOtp(String code) async {
    final phone = switch (state) {
      AwaitingOtp(:final phone) => phone,
      _ => throw StateError('Not awaiting OTP'),
    };
    final result = await ref
        .read(authRepositoryProvider)
        .verifyOtp(phone, code);
    state = SignedIn(result.profile);
  }

  /// The signed-in profile, or null when not signed in.
  Profile? get currentProfile => switch (state) {
    SignedIn(:final profile) => profile,
    _ => null,
  };

  /// Set/update the signed-in user's profile (onboarding name-setup + edits).
  /// Swapping the profile drives the onboarding redirect (null first_name → /welcome).
  Future<void> updateProfile({
    required String firstName,
    String? lastName,
  }) async {
    final updated = await ref
        .read(profileRepositoryProvider)
        .updateProfile(firstName: firstName, lastName: lastName);
    state = SignedIn(updated);
  }

  /// Return to the phone-entry step.
  void cancelOtp() => state = const SignedOut();

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const SignedOut();
  }

  /// Called by the ApiClient when token refresh fails irrecoverably.
  void forceSignOut() => state = const SignedOut();
}
