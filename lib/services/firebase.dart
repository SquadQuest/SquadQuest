import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:squadquest/controllers/profile.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/firebase_options.dart';

export 'package:firebase_core/firebase_core.dart';

final firebaseAppProvider = Provider<FirebaseApp>((_) {
  throw UnimplementedError();
});

final firebaseMessagingServiceProvider =
    Provider<FirebaseMessagingService>((ref) {
  return FirebaseMessagingService(ref);
});

final firebaseMessagingTokenProvider = StateProvider<String?>((_) => null);

final firebaseMessagingStreamProvider = StreamProvider<RemoteMessage>((ref) {
  final firebaseMessagingService = ref.watch(firebaseMessagingServiceProvider);
  return firebaseMessagingService.stream;
});

Future<FirebaseApp> buildFirebaseApp() async {
  loggerNoStack.t('buildFirebaseApp');

  final app = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  return app;
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await buildFirebaseApp();

  loggerNoStack.t({'message:background': message});
}

class FirebaseMessagingService {
  final Ref ref;
  late final FirebaseMessaging messaging;
  NotificationSettings? settings;
  late final String? token;
  final _streamController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get stream => _streamController.stream;

  FirebaseMessagingService(this.ref) {
    _init();
  }

  void _init() async {
    loggerNoStack.t('FirebaseMessagingService._init');

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
      loggerNoStack.i('Got FCM token: $token');
    } catch (error) {
      logger.e('Error getting FCM token', error: error);
    }

    // save FCM token to profile—main forced the service to initialize before the app is run so profile will never be set already
    ref.listen(profileProvider, (previous, profile) async {
      loggerNoStack.i(
          {'profile:previous': previous?.value, 'profile:next': profile.value});
      if (profile.value != null &&
          token != null &&
          profile.value!.fcmToken != token) {
        await ref.read(profileProvider.notifier).patch({
          'fcm_token': token,
        });
      }
    });

    // listen for foreground and background messages
    FirebaseMessaging.onMessage.listen((message) => _onMessage(message, false));

    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _onMessage(initialMessage, true);
    }

    FirebaseMessaging.onMessageOpenedApp
        .listen((message) => _onMessage(message, true));
  }

  void _onMessage(RemoteMessage message, bool? wasBackground) {
    loggerNoStack
        .t({'message:foreground': message, 'background': wasBackground});

    _streamController.add(message);
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
