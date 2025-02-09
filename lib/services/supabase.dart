import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
export 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

import 'package:squadquest/logger.dart';

// Core providers
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return ref.watch(supabaseProvider).requireValue;
});

// Initialization provider
final supabaseProvider = FutureProvider<SupabaseClient>((ref) async {
  logger.t('Initializing Supabase');

  final supabaseUrl = dotenv.get('SUPABASE_URL');
  final supabaseAnonKey = dotenv.get('SUPABASE_ANON_KEY');

  final supabase = await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Set up auth state change listener for Sentry integration
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
  });

  return supabase.client;
});

// Auth state changes stream
final supabaseAuthStateChangesProvider = StreamProvider<AuthState?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

// For backward compatibility during migration
final supabaseInitialized = supabaseProvider.future;

// For testing
void mockSupabaseInitializedComplete() {
  // no-op as initialization is now handled by the provider
}
