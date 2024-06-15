import 'dart:developer';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:squadquest/controllers/profile.dart';

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
  log('buildFirebaseApp');

  final app = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  return app;
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await buildFirebaseApp();

  log("Handling a background message: ${message.messageId} data=${message.data}");
  inspect(message);

  if (message.notification != null) {
    log('Background message also contained a notification:\n\ttitle: ${message.notification?.title}\n\tbody: ${message.notification?.body}');
  }
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
    log('FirebaseMessagingService._init');

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
    } catch (error) {
      log('Error getting FCM token: $error');
    }

    // save FCM token to profile—main forced the service to initialize before the app is run so profile will never be set already
    ref.listen(profileProvider, (_, profile) async {
      log('FirebaseMessagingService._init.onProfileChange: profile=${profile.value}, token=$token');
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
    log('FirebaseMessagingService._onMessage: wasBackground=$wasBackground messageId=${message.messageId} data=${message.data}');
    inspect(message);

    if (message.notification != null) {
      log('Foreground message also contained a notification:\n\ttitle: ${message.notification?.title}\n\tbody: ${message.notification?.body}');
    }

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
      log('Error requesting FCM permissions: $error');
      return null;
    }
  }
}
