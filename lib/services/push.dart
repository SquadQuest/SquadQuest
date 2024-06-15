import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:squadquest/controllers/auth.dart';
// import 'package:rxdart/rxdart.dart';

import 'package:squadquest/services/supabase.dart';

final pushServiceProvider =
    NotifierProvider<PushService, String?>(PushService.new);

class PushService extends Notifier<String?> {
  PushService();

  late FirebaseMessaging _messaging;
  late NotificationSettings _settings;

  @override
  String? build() {
    ref
        .read(authControllerProvider.notifier)
        .onAuthenticated(_initializeFirebase);
    return null;
  }

  Future<void> _initializeFirebase(Session session) async {
    log('PushService._initializeFirebase: user.id=${session.user.id}');
    inspect(session);

    _messaging = FirebaseMessaging.instance;

    // request permissions
    _settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // get token
    debugger();
    final token =
        await _messaging.getToken(vapidKey: dotenv.get('FCM_VAPID_KEY'));

    state =
        token; // TODO: store something more useful? _messaging if it's cached?

    // save token to profile
    final supabase = ref.read(supabaseProvider);
    await supabase
        .from('profiles')
        .update({'fcm_token': token}).eq('id', session.user.id);

    // listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Got a message whilst in the foreground!');
      log('Message data: ${message.data}');
      inspect(message);

      if (message.notification != null) {
        log('Message also contained a notification: ${message.notification}');
      }
    });
  }
}
