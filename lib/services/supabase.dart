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
  logger.t('Initializing Supabase');

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
      logger.t('Successfully tested new Supabase key');
      keyToUse = supabaseAnonKey;
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Unexpected status code: ${response.statusCode}',
      );
    }
  } catch (error) {
    logger.w('Failed to test new Supabase key, falling back to legacy key',
        error: error);
    keyToUse = supabaseAnonKeyLegacy;
  }

  // Initialize Supabase with the working key
  final supabase = await Supabase.initialize(
    url: supabaseUrl,
    anonKey: keyToUse,
  );

  logger.t(
      'Successfully initialized Supabase with ${keyToUse == supabaseAnonKey ? 'new' : 'legacy'} key');

  // Set up auth state change listener for Sentry integration
  supabase.client.auth.onAuthStateChange.listen((data) {
    logger.t({
      'supabase.onAuthStateChange': {
        'event': data.event.toString(),
        'session': data.session,
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
  });

  return supabase;
});

// Auth state changes stream
final supabaseAuthStateChangesProvider = StreamProvider<AuthState?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});
