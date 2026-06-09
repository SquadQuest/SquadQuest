/// Build-time configuration.
///
/// Endpoint config is passed via --dart-define (compile-time), not a runtime
/// .env, since the base URL has no secrets and varies per build target:
///   flutter run --dart-define=API_BASE_URL=https://api.squadquest.app
/// (Android emulator → http://10.0.2.2:4000 to reach a host-local server.)
/// NOTE: this is a deliberate divergence from the mobile-flutter skill's .env
/// convention — reserve .env for runtime secrets, which the client has none of yet.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:4000',
);

/// Sent as X-SquadQuest-Client on every request (telemetry + upgrade floor).
/// TODO: derive from package_info_plus once release versioning is wired up.
const clientHeader = 'macos/0.1.0+1';
