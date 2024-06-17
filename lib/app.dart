import 'dart:html';

import 'package:squadquest/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    // TODO: move logic to router.dart somehow?
    document.window?.addEventListener('message', (Event event) {
      var data = (event as MessageEvent).data;
      logger.i({'onBrowserMessage': data});

      if (data['action'] == 'redirect-from-notificationclick') {
        if (data['action'].substring(0, 9) == '#/events/') {
          _scaffoldKey.currentContext?.push(data['action'].substring(2));
        }
      }
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
