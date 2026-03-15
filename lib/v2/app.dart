import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/theme.dart';

import 'screens/shell.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AppShell(),
    ),
  ],
);

class V2App extends ConsumerWidget {
  const V2App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SquadQuest',
      theme: appThemeLight,
      darkTheme: appThemeDark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
