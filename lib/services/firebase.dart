import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/router.dart';
import 'package:squadquest/firebase_options.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/services/preferences.dart';
import 'package:squadquest/controllers/calendar.dart';
import 'package:squadquest/components/forms/notifications.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/interop/set_handler.stub.dart'
    if (dart.library.html) 'package:squadquest/interop/set_handler.web.dart';

export 'package:firebase_messaging/firebase_messaging.dart' show RemoteMessage;

typedef FirebaseStreamRecord = ({String type, RemoteMessage message});

// Core provider that handles initialization
final firebaseProvider = FutureProvider<FirebaseApp>((ref) async {
  log('Initializing Firebase');

  final app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  return app;
});

final firebaseMessagingServiceProvider =
    Provider<FirebaseMessagingService>((ref) {
  return FirebaseMessagingService(ref);
});

final firebaseMessagingTokenProvider = StateProvider<String?>((_) => null);

final firebaseMessagingStreamProvider =
    StreamProvider<FirebaseStreamRecord>((ref) {
  final firebaseMessagingService = ref.watch(firebaseMessagingServiceProvider);
  return firebaseMessagingService.stream;
});

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background handler
  final app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  logger.t({
    'message:background': {
      'message-id': message.messageId,
      'message-type': message.messageType,
      'notification-title': message.notification?.title,
      'notification-body': message.notification?.body,
    }
  });

  // Handle invitation notifications in background
  if (message.data['notificationType'] == 'invitation') {
    final data =
        message.data['json'] == null ? {} : jsonDecode(message.data['json']);

    try {
      // Check if calendar writing is enabled
      final prefs = await SharedPreferences.getInstance();
      final calendarWritingEnabled =
          prefs.getString('calendarWritingEnabled') == 'true';

      if (calendarWritingEnabled) {
        final instance = Instance.fromMap(data['event']);
        final subscription = InstanceMember.fromMap(data['invitation']);

        await CalendarController.instance.upsertEvent(
          instance: instance,
          subscription: subscription,
        );
      }
    } catch (error) {
      logger.e('Error writing calendar event in background', error: error);
    }
  }
}

class FirebaseMessagingService {
  final Ref ref;
  late final FirebaseMessaging messaging;
  NotificationSettings? settings;
  String? token;

  String? _writtenToken;
  late final PackageInfo _platformInfo;
  final _streamController = StreamController<FirebaseStreamRecord>.broadcast();
  Stream<FirebaseStreamRecord> get stream => _streamController.stream;
  bool _requestingPermission = false;

  FirebaseMessagingService(this.ref) {
    _init();
  }

  void _init() async {
    log('FirebaseMessagingService._init');

    // load package version/build information
    _platformInfo = await PackageInfo.fromPlatform();

    // obtain FCM instance
    messaging = FirebaseMessaging.instance;

    // configure notification presentation
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // save FCM token on refresh
    messaging.onTokenRefresh.listen((token) async {
      this.token = token;
      await _writeToken();
    });

    // listen for foreground and background messages
    FirebaseMessaging.onMessage.listen((message) => _onMessage(message));

    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _onMessageOpened(initialMessage);
    }

    // handle interaction with background notifications
    // - NOTE: this does not currently work on the web because Flutter hasn't figured out how to communicate from the service worker back to the UI thread
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // catch notification clicks on web
    if (kIsWeb) {
      // set a global handler on window instead of listening to messages to ensure there is only ever a single handler across hot reloads
      setWebHandler('onWebNotificationOpened', _onWebNotificationOpened);
    }

    // save FCM token to profile—main forced the service to initialize before the app is run so profile will never be set already
    ref.listen(profileProvider, (previous, profile) async {
      if (profile.isLoading) return;
      await _writeToken();

      if (profile.value != null) {
        await Future.delayed(const Duration(seconds: 2));
        await requestPermissions();
      }
    }, fireImmediately: true);
  }

  Future<void> _writeToken() async {
    final profile = ref.read(profileProvider);

    // skip if token or profile is null or if this token has already been written
    if (token == null ||
        profile.isLoading ||
        !profile.hasValue ||
        profile.value == null ||
        token == _writtenToken) {
      return;
    }

    log('Writing FCM token to profile: $token');
    _writtenToken = token;

    await ref.read(profileProvider.notifier).patch({
      'fcm_token': token,
      'fcm_token_updated_at': DateTime.now().toUtc().toIso8601String(),
      'fcm_token_app_build': int.parse(_platformInfo.buildNumber),
    });
  }

  void _onMessage(RemoteMessage message) {
    log('Firebase message received');
    logger.d(message);

    _streamController.add((type: 'message-received', message: message));
  }

  void _onMessageOpened(RemoteMessage message) {
    log('Firebase message opened');
    logger.d(message);

    _streamController.add((type: 'notification-opened', message: message));
  }

  void _onWebNotificationOpened(Map data) {
    final message = RemoteMessage(
        messageType: data['messageType'],
        messageId: data['messageId'],
        data: {
          'notificationType': data['data']?['notificationType'],
          'url': data['data']?['url'],
          'json': data['data']?['json'],
        });

    log('Firebase web notification opened');
    logger.d(message);

    _streamController.add((type: 'notification-opened', message: message));
  }

  Future<void> requestPermissions() async {
    if (settings != null || _requestingPermission) return;

    log('fcm: requesting permissions...');
    _requestingPermission = true;

    final prefs = ref.read(preferencesProvider).requireValue;
    final confirmedNotificationPermission =
        prefs.getBool('confirmedNotificationPermission');

    if (confirmedNotificationPermission != true) {
      await showDialog<void>(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Notifications'),
          contentPadding: const EdgeInsets.all(0),
          content: const SingleChildScrollView(
              child: Column(children: [
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child:
                    Text('SquadQuest isn\'t very useful without notifications,'
                        ' you\'ll be asked next to grant the app permission to'
                        ' show them.\n\nYou can review what you\'ll be notified'
                        ' about below, or any time from the settings screen:')),
            NotificationOptions()
          ])),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      prefs.setBool('confirmedNotificationPermission', true);
    }

    try {
      log('requesting permissions');
      settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      log('got permissions: $settings');
    } catch (error) {
      logger.e('fcm: error requesting permissions', error: error);
    }

    // wait for 5 seconds before getting the token... seems to help it work on iOS the first time
    await Future.delayed(const Duration(seconds: 5));

    // get FCM device token
    try {
      log('getting APNS token');
      final apnsToken = await messaging.getAPNSToken();
      log('got APNS token: $apnsToken');
      token = await messaging.getToken(vapidKey: dotenv.get('FCM_VAPID_KEY'));
      log('got FCM token: $token');
      ref.read(firebaseMessagingTokenProvider.notifier).state = token;
      log('wrote FCM token to provider');
      await _writeToken();
      log('wrote FCM token to profile');
    } catch (error) {
      logger.e('fcm: error getting token', error: error);
    }

    _requestingPermission = false;
  }
}
