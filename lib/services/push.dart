import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:squadquest/services/supabase.dart';

final pushServiceProvider =
    AsyncNotifierProvider<PushService, String?>(PushService.new);

class PushService extends AsyncNotifier<String?> {
  PushService();

  late FirebaseMessaging _messaging;
  late NotificationSettings _settings;

  @override
  String? build() {
    _messaging = FirebaseMessaging.instance;

    _messaging
        .requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    )
        .then((settings) async {
      final supabase = ref.read(supabaseProvider);
      _settings = settings;
      final token = await _messaging.getToken();
      state = AsyncValue.data(token);

      await supabase
          .from('profiles')
          .update({'fcm_token': token}).eq('id', supabase.auth.currentUser!.id);
    });

    return null;
  }
}
