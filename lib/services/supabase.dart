import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';

import 'package:squadquest/logger.dart';

export 'package:supabase_flutter/supabase_flutter.dart';

// Core providers
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return ref.watch(supabaseProvider).requireValue.client;
});

// Initialization provider
final supabaseProvider = FutureProvider<Supabase>((ref) async {
  log('Initializing Supabase');

  final supabaseUrl = dotenv.get('SUPABASE_URL');
  final supabaseAnonKey = dotenv.get('SUPABASE_ANON_KEY');
  final supabaseAnonKeyLegacy = dotenv.get('SUPABASE_ANON_KEY_LEGACY');

  // Test if the new key works by making a direct API call
  final dio = Dio();
  String keyToUse;

  try {
    final response = await dio.get(
      '$supabaseUrl/rest/v1/app_versions?select=*&limit=1',
      options: Options(
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
        },
      ),
    );

    if (response.statusCode == 200) {
      log('Successfully tested new Supabase key');
      keyToUse = supabaseAnonKey;
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Unexpected status code: ${response.statusCode}',
      );
    }
  } catch (error) {
    log('Failed to test new Supabase key, falling back to legacy key');
    keyToUse = supabaseAnonKeyLegacy;
  }

  // Initialize Supabase with the working key
  final supabase = await Supabase.initialize(
    url: supabaseUrl,
    anonKey: keyToUse,
  );

  log('Successfully initialized Supabase with ${keyToUse == supabaseAnonKey ? 'new' : 'legacy'} key');

  // A session restored from storage after the app has sat unused carries an
  // expired access token. PostgREST reads the token per request so it recovers
  // once a refresh lands, but the realtime client captures whatever token it
  // holds when a channel subscribes -- so without this, the first channels come
  // up with a dead JWT and the server rejects them ("Token has expired N
  // seconds ago"). Refresh before anything subscribes.
  final restored = supabase.client.auth.currentSession;
  if (restored != null && restored.isExpired) {
    log('Restored session token is expired, refreshing before subscribing');
    try {
      await supabase.client.auth.refreshSession();
      log('Refreshed session');
    } catch (error, stackTrace) {
      // A refresh token that's been revoked or has aged out can't be recovered
      // here; let the app start signed-out rather than blocking on it.
      logger.e('Failed to refresh restored session',
          error: error, stackTrace: stackTrace);
    }
  }

  // Set up auth state change listener for Sentry integration
  supabase.client.auth.onAuthStateChange.listen((data) {
    log('Supabase authStateChange: ${data.event}');
    logger.d(data.session);

    // integrate with Sentry
    final sentryUser = data.session == null
        ? null
        : SentryUser(
            id: data.session?.user.id,
            name: data.session?.user.userMetadata?['first_name'],
          );
    Sentry.configureScope((scope) => scope.setUser(sentryUser));
  });

  return supabase;
});

// Auth state changes stream
final supabaseAuthStateChangesProvider = StreamProvider<AuthState?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});
