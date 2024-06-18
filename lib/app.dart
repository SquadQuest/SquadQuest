import 'dart:convert';

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
    ref.listen(firebaseMessagingStreamProvider, (previous, record) {
      final (:type, :message) = record.value!;

      switch (type) {
        case 'message-received':
          _scaffoldKey.currentState?.showSnackBar(SnackBar(
              content: Text(
                  '${message.notification?.title ?? ''}\n\n${message.notification?.body ?? ''}')));

        case 'notification-opened':
          final navContext = navigatorKey.currentContext;
          final data = jsonDecode(message.data['json']);

          if (navContext == null) return;

          switch (message.data['notificationType']) {
            case 'rsvp':

              // if the top of the stack is the event details page, replace it
              final go =
                  router.routerDelegate.currentConfiguration.last.route.name ==
                          'event-details'
                      ? navContext.pushReplacementNamed
                      : navContext.pushNamed;

              go('event-details',
                  pathParameters: {'id': data['event']['id'] as String});
            case 'friend-request-received':
            case 'friend-request-accepted':
              navContext.goNamed('friends');
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
