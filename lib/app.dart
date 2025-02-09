import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/router.dart';
import 'package:squadquest/services/notifications.dart';
import 'package:squadquest/theme.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/ui/core/app_startup.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final routerService = ref.watch(routerProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'SquadQuest',
      theme: appThemeLight,
      darkTheme: appThemeDark,
      themeMode: themeMode,
      routerConfig: routerService.router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return AppStartupWidget(
          onLoaded: (_) => child!,
        );
      },
    );
  }
}
