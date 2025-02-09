import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/router.dart';
import 'package:squadquest/ui/core/app_startup.dart';
import 'package:squadquest/controllers/settings.dart';

class RootAppWidget extends ConsumerWidget {
  const RootAppWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      routerConfig: router.router,
      themeMode: themeMode,
      builder: (context, child) {
        return AppStartupWidget(
          onLoaded: (_) => child!,
        );
      },
    );
  }
}
