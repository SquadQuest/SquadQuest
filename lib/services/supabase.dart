import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

export 'package:supabase_flutter/supabase_flutter.dart';

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

Future<Supabase> buildSupabaseApp(DotEnv dotEnv) async {
  log('buildSupabaseApp');
  return Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    anonKey: dotenv.get('SUPABASE_ANON_KEY'),
  );
}
