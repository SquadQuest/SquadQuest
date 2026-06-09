import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the access + refresh tokens for the session, persisting them to the
/// platform secure store (Keychain/Keystore) when available.
///
/// The in-memory fields are the source of truth for the running session; the
/// secure store is the persistence layer. Persistence failures are tolerated
/// (logged in debug, swallowed) so a platform-keychain issue never breaks auth —
/// notably on **unsigned** macOS dev/CI builds, where the keychain rejects access
/// (errSecMissingEntitlement / errSecInteractionNotAllowed). Signed builds
/// (production) persist normally and survive relaunch.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // File-based (not data-protection) keychain on macOS; the
            // data-protection keychain additionally requires app signing.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  String? accessToken;
  String? refreshToken;

  Future<void> load() async {
    try {
      accessToken = await _storage.read(key: _accessKey);
      refreshToken = await _storage.read(key: _refreshKey);
    } catch (e) {
      _warn('read', e);
    }
  }

  Future<void> save({required String access, required String refresh}) async {
    accessToken = access;
    refreshToken = refresh;
    try {
      await _storage.write(key: _accessKey, value: access);
      await _storage.write(key: _refreshKey, value: refresh);
    } catch (e) {
      _warn('write', e); // session continues in-memory
    }
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (e) {
      _warn('delete', e);
    }
  }

  bool get hasSession => refreshToken != null;

  void _warn(String op, Object e) {
    if (kDebugMode) {
      debugPrint(
        'TokenStore: secure-store $op failed (continuing in-memory): $e',
      );
    }
  }
}
