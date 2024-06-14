import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/router.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/controllers/settings.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final profile = ref.read(profileProvider);

    if (profile.hasValue) {
      if (profile.value == null) {
        router.go('/profile');
      }
    } else {
      ref.listen(profileProvider, (previous, next) {
        if (next.hasValue && next.value == null) {
          Future.delayed(
              const Duration(seconds: 1), () => router.go('/profile'));
        }
      });
    }

    return MaterialApp.router(
      title: 'Squad Quest',
      theme: ThemeData(),
      darkTheme: ThemeData.dark(),
      themeMode: themMode,
      routerConfig: router,
    );
  }
}
