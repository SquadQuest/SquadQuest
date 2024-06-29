import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/firebase_options.dart';
import 'package:squadquest/controllers/profile.dart';
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
  final _streamController = StreamController<FirebaseStreamRecord>.broadcast();
  Stream<FirebaseStreamRecord> get stream => _streamController.stream;

  FirebaseMessagingService(this.ref) {
    _init();
  }

  void _init() async {
    logger.t('FirebaseMessagingService._init');

    messaging = FirebaseMessaging.instance;

    // request permissions
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // get FCM device token
    try {
      token = await messaging.getToken(vapidKey: dotenv.get('FCM_VAPID_KEY'));
      logger.i('Got FCM token: $token');
      ref.read(firebaseMessagingTokenProvider.notifier).state = token;
    } catch (error) {
      logger.e('Error getting FCM token', error: error);
    }

    // save FCM token to profile—main forced the service to initialize before the app is run so profile will never be set already
    ref.listen(profileProvider, (previous, profile) async {
      logger.i({
        'profile:previous': previous?.value,
        'profile:next----': profile.value
      });
      if (profile.value != null &&
          token != null &&
          profile.value!.fcmToken != token) {
        await ref.read(profileProvider.notifier).patch({
          'fcm_token': token,
        });
      }
    });

    // save FCM token on refresh
    messaging.onTokenRefresh.listen((token) async {
      this.token = token;

      final profile = ref.read(profileProvider);
      if (profile.value != null) {
        await ref.read(profileProvider.notifier).patch({
          'fcm_token': token,
        });
      }
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

  Future<NotificationSettings?> requestPermissions() async {
    if (settings != null) return settings!;

    try {
      return settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (error) {
      logger.e('Error requesting FCM permissions', error: error);
      return null;
    }
  }
}
