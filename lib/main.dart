import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:logger/logger.dart';
import 'package:device_preview/device_preview.dart';

import 'package:squadquest/app.dart';
import 'package:squadquest/logger.dart';
import 'package:squadquest/services/preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Activate path-based routing URL strategy for web
  usePathUrlStrategy();

  // Register error handlers
  registerErrorHandlers();

  // Load .env file
  await dotenv.load(fileName: ".env");

  // Initialize SharedPreferences
  final container = ProviderContainer();
  await container.read(preferencesProvider.future);

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
    appRunner: () => runApp(
      UncontrolledProviderScope(
        container: container,
        child: kDebugMode
            ? DevicePreview(
                enabled: !kIsWeb && Platform.isMacOS,
                defaultDevice: Devices.ios.iPhoneSE,
                backgroundColor: Colors.black87,
                builder: (context) => const MyApp(),
                tools: const [
                  DeviceSection(),
                  SystemSection(),
                ],
              )
            : const MyApp(),
      ),
    ),
  );
}

void registerErrorHandlers() {
  // Show some error UI if any uncaught exception happens
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logger.e(
      'Uncaught UI exception',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Handle errors from the underlying platform/OS
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logger.e(
      'Uncaught platform exception',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  // Show some error UI when any widget in the app fails to build
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: Text('An error occurred'),
      ),
      body: Center(child: Text(details.toString())),
    );
  };

  // Integrate logger with Sentry
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
}
