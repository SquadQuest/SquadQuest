import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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

Future<Supabase> buildSupabaseApp() async {
  log('buildSupabaseApp');

  // TODO: eventually delete the legacy key logic

  final supabaseUrl = dotenv.get('SUPABASE_URL');
  final supabaseAnonKey = dotenv.get('SUPABASE_ANON_KEY');
  final supabaseAnonKeyLegacy = dotenv.get('SUPABASE_ANON_KEY_LEGACY');

  // execute test API call to determine which key to use
  final response = await http
      .get(Uri.parse('$supabaseUrl/rest/v1/test?select=success'), headers: {
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer $supabaseAnonKey'
  });

  // initialize app with appropriate key
  return Supabase.initialize(
      url: supabaseUrl,
      anonKey:
          response.statusCode == 401 ? supabaseAnonKeyLegacy : supabaseAnonKey);
}
