import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:logger/logger.dart';

import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/app.dart';

// TODO: setup background geolocation headless: https://github.com/transistorsoft/flutter_background_geolocation/blob/master/help/INSTALL-ANDROID.md#android-headless-mode-with-enableheadless-true

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Activate path-based routing URL strategy for web
  usePathUrlStrategy();

  // Load .env file
  await dotenv.load(fileName: ".env");

  // Initialize Shared Preferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize Supabase
  final supabaseApp = await buildSupabaseApp();

  // Initialize Firebase
  final firebaseApp = await buildFirebaseApp();

  // Initialize a custom provider container
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    supabaseAppProvider.overrideWithValue(supabaseApp),
    firebaseAppProvider.overrideWithValue(firebaseApp),
  ]);

  // Initialize any providers that need to be always-on
  container.read(firebaseMessagingServiceProvider);
  container.read(settingsControllerProvider);

  // integrate logger with Sentry
  Logger.addLogListener((LogEvent event) {
    switch (event.level) {
      case Level.error:
      case Level.fatal:
        Sentry.captureException(event.error, stackTrace: event.stackTrace);
      case Level.warning:
        Sentry.captureMessage(event.message.toString(),
            params: event.message is Map ? event.message : null,
            level: SentryLevel.warning);
      default:
        Sentry.addBreadcrumb(Breadcrumb(
          message: event.message is String
              ? event.message
              : event.message.toString(),
          data: event.message is Map ? event.message : null,
          level: switch (event.level) {
            Level.debug => SentryLevel.debug,
            _ => SentryLevel.info,
          },
        ));
    }
  });

  // Run the app, wrapped w/ Sentry
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://c492ee2823d5fe451dab50b6a591f2af@o4507618757705728.ingest.us.sentry.io/4507618760916992';
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;

      options.attachViewHierarchy = true;
    },
    appRunner: () => runApp(UncontrolledProviderScope(
      container: container,
      child: MyApp(),
    )),
  );
}
