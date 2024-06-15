import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/router.dart';
import 'package:squadquest/theme.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/services/firebase.dart';

class MyApp extends ConsumerWidget {
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    // (temporarily)? display any push notification in-app
    ref.listen(firebaseMessagingStreamProvider, (previous, message) {
      if (message.value?.notification == null) return;

      _scaffoldKey.currentState?.showSnackBar(SnackBar(
          content: Text(
              '${message.value?.notification?.title ?? ''}\n\n${message.value?.notification?.body ?? ''}')));
    });

    return MaterialApp.router(
      scaffoldMessengerKey: _scaffoldKey,
      title: 'SquadQuest',
      theme: appThemeLight,
      darkTheme: appThemeDark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
