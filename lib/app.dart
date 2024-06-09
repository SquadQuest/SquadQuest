import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/screens/splash.dart';
import 'package:squad_quest/controllers/settings.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themMode = ref.watch(themeModeProvider);

    return MaterialApp(
        title: 'Squad Quest',
        theme: ThemeData(),
        darkTheme: ThemeData.dark(),
        themeMode: themMode,
        home: const SplashView());
  }
}
