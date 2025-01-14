import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
export 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

import 'package:squadquest/logger.dart';

final supabaseAppProvider = Provider<Supabase>((ref) {
  throw UnimplementedError();
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final supabase = ref.watch(supabaseAppProvider);
  return supabase.client;
});

final supabaseAuthStateChangesProvider = StreamProvider<AuthState?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
});

final Completer _supabaseInitializedCompleter = Completer<void>();
final supabaseInitialized = _supabaseInitializedCompleter.future;

Future<Supabase> buildSupabaseApp() async {
  logger.t('buildSupabaseApp');

  // TODO: eventually delete the legacy key logic

  final supabaseUrl = dotenv.get('SUPABASE_URL');
  final supabaseAnonKey = dotenv.get('SUPABASE_ANON_KEY');
  final supabaseAnonKeyLegacy = dotenv.get('SUPABASE_ANON_KEY_LEGACY');
  Supabase supabase;

  // execute test API call to determine which key to use
  final dio = Dio();
  try {
    // try new key
    await dio.get('$supabaseUrl/rest/v1/test?select=success',
        options: Options(headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey'
        }));

    // initialize app with new key
    supabase =
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } catch (error) {
    // fallback to legacy key
    supabase = await Supabase.initialize(
        url: supabaseUrl, anonKey: supabaseAnonKeyLegacy);
  }

  final authSubscription =
      supabase.client.auth.onAuthStateChange.listen((data) {
    logger.t({
      'supabase.onAuthStateChange': {
        'event': data.event.toString(),
        'session': data.session,
        'session.user': data.session?.user
      }
    });

    // integrate with Sentry
    final sentryUser = data.session == null
        ? null
        : SentryUser(
            id: data.session?.user.id,
            name: data.session?.user.userMetadata?['first_name'],
          );
    Sentry.configureScope((scope) => scope.setUser(sentryUser));

    // complete supabaseInitialized future when session is available
    if (data.event == AuthChangeEvent.initialSession) {
      logger.t('supabase initialized');
      _supabaseInitializedCompleter.complete();
    }
  });

  authSubscription.onError((error, stackTrace) {
    logger.e({'supabase.authSubscription.onError': error},
        stackTrace: stackTrace);
  });

  return supabase;
}

void mockSupabaseInitializedComplete() {
  _supabaseInitializedCompleter.complete();
}
