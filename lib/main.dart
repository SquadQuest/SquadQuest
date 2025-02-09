import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:logger/logger.dart';
import 'package:device_preview/device_preview.dart';

import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/services/initialization.dart';
import 'package:squadquest/ui/core/root_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Activate path-based routing URL strategy for web
  usePathUrlStrategy();

  // Load .env file
  await dotenv.load(fileName: ".env");

  // Initialize a custom provider container
  final container = ProviderContainer();

  // Initialize core services
  await container.read(initializationProvider.future);

  // Initialize messaging service
  container.read(firebaseMessagingServiceProvider);

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
        child: DevicePreview(
          enabled: !kIsWeb && Platform.isMacOS,
          defaultDevice: Devices.ios.iPhoneSE,
          backgroundColor: Colors.black87,
          builder: (context) => const RootAppWidget(),
          tools: const [
            DeviceSection(),
            SystemSection(),
          ],
        ))),
  );
}
