import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: ".env");

  // Initialize Shared Preferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize Supabase
  final supabaseApp = await buildSupabaseApp();

  // Initialize Firebase
  final firebaseApp = await buildFirebaseApp();

  // Initialize a custom provider container
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    supabaseAppProvider.overrideWithValue(supabaseApp),
    firebaseAppProvider.overrideWithValue(firebaseApp),
  ]);

  // Initialize any providers that need to be always-on
  container.read(firebaseMessagingServiceProvider);
  container.read(settingsControllerProvider);

  // Run the app
  runApp(UncontrolledProviderScope(
    container: container,
    child: MyApp(),
  ));
}
