import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/router.dart';
import 'package:squadquest/firebase_options.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/components/forms/notifications.dart';
import 'package:squadquest/interop/set_handler.stub.dart'
    if (dart.library.html) 'package:squadquest/interop/set_handler.web.dart';

export 'package:firebase_messaging/firebase_messaging.dart' show RemoteMessage;

typedef FirebaseStreamRecord = ({String type, RemoteMessage message});

final firebaseAppProvider = Provider<FirebaseApp>((_) {
  throw UnimplementedError();
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

Future<FirebaseApp> buildFirebaseApp() async {
  logger.t('buildFirebaseApp');

  final app = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  return app;
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await buildFirebaseApp();

  logger.t({
    'message:background': {
      'message-id': message.messageId,
      'message-type': message.messageType,
      'notification-title': message.notification?.title,
      'notification-body': message.notification?.body,
    }
  });
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
    logger.t('FirebaseMessagingService._init');

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

    logger.i('Writing FCM token to profile: $token');
    _writtenToken = token;

    await ref.read(profileProvider.notifier).patch({
      'fcm_token': token,
      'fcm_token_updated_at': DateTime.now().toUtc().toIso8601String(),
      'fcm_token_app_build': int.parse(_platformInfo.buildNumber),
    });
  }

  void _onMessage(RemoteMessage message) {
    logger.t({
      'message:received': {
        'message-id': message.messageId,
        'message-type': message.messageType,
        'notification-title': message.notification?.title,
        'notification-body': message.notification?.body,
      }
    });

    _streamController.add((type: 'message-received', message: message));
  }

  void _onMessageOpened(RemoteMessage message) {
    logger.t({
      'message:opened': {
        'message-id': message.messageId,
        'message-type': message.messageType,
        'notification-title': message.notification?.title,
        'notification-body': message.notification?.body,
      }
    });
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

    logger.t({
      'notification:opened-web': {
        'message-id': message.messageId,
        'message-type': message.messageType,
        'notification-title': message.notification?.title,
        'notification-body': message.notification?.body,
      }
    });

    _streamController.add((type: 'notification-opened', message: message));
  }

  Future<void> requestPermissions() async {
    if (settings != null || _requestingPermission) return;

    logger.t('fcm: requesting permissions...');
    _requestingPermission = true;

    final prefs = ref.read(sharedPreferencesProvider);
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
      logger.t('requesting permissions');
      settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      logger.t('got permissions: $settings');
    } catch (error) {
      logger.e('fcm: error requesting permissions', error: error);
    }

    // wait for 5 seconds before getting the token... seems to help it work on iOS the first time
    await Future.delayed(const Duration(seconds: 5));

    // get FCM device token
    try {
      logger.t('getting APNS token');
      final apnsToken = await messaging.getAPNSToken();
      logger.t('got APNS token: $apnsToken');
      token = await messaging.getToken(vapidKey: dotenv.get('FCM_VAPID_KEY'));
      logger.t('got FCM token: $token');
      ref.read(firebaseMessagingTokenProvider.notifier).state = token;
      logger.t('wrote FCM token to provider');
      await _writeToken();
      logger.t('wrote FCM token to profile');
    } catch (error) {
      logger.e('fcm: error getting token', error: error);
    }

    _requestingPermission = false;
  }
}
