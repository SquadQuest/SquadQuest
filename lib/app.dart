import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/router.dart';
import 'package:squadquest/theme.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/controllers/location.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/screens/splash.dart';

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
      final data =
          message.data['json'] == null ? {} : jsonDecode(message.data['json']);

      switch (type) {
        case 'message-received':
          switch (message.data['notificationType']) {
            case 'friend-request-accepted':
              final profilesCache = ref.read(profilesCacheProvider.notifier);

              // load expanded profile data into cache
              final friendProfile =
                  UserProfile.fromMap(data['friendship']['requestee']);

              profilesCache.cacheProfiles([friendProfile]);

              // force friends list to refresh
              ref.read(friendsProvider.notifier).refresh();

              // refresh network
              profilesCache.loadNetwork();
            case 'friend-request-received':
              // load expanded profile data into cache
              final friendProfile =
                  UserProfile.fromMap(data['friendship']['requester']);
              ref
                  .read(profilesCacheProvider.notifier)
                  .cacheProfiles([friendProfile]);

              // force friends list to refresh
              ref.read(friendsProvider.notifier).refresh();
            case 'event-ended':
              ref
                  .read(locationControllerProvider)
                  .stopTracking(data['event']['id']);
          }
          // (temporarily)? display any push notification in-app
          _scaffoldKey.currentState?.showSnackBar(SnackBar(
              content: Text(
                  '${message.notification?.title ?? ''}\n\n${message.notification?.body ?? ''}')));

        case 'notification-opened':
          logger.t({
            'notification-opened': {
              'message-id': message.messageId,
              'message-type': message.messageType,
              'notification-title': message.notification?.title,
              'notification-body': message.notification?.body,
              'notification-type': type,
              'data': data,
            }
          });

          switch (message.data['notificationType']) {
            case 'event-posted':
            case 'event-canceled':
            case 'event-uncanceled':
            case 'rally-point-updated':
            case 'rsvp':
              goToNotificationRoute(ref, '/events/${data['event']['id']}');
            case 'invitation':
              goToNotificationRoute(
                  ref, '/events/${data['invitation']['instance']}');
            case 'friend-request-received':
            case 'friend-request-accepted':
              goToNotificationRoute(ref, '/friends');
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
      debugShowCheckedModeBanner: false,
    );
  }

  Future<void> goToNotificationRoute(WidgetRef ref, String location) async {
    final navContext = navigatorKey.currentContext;
    final router = ref.read(routerProvider);

    logger.t({
      'goToNotificationRoute': {'location': location}
    });

    if (navContext == null) {
      logger.t('goToNotificationRoute: navigatorKey.currentContext is null');
      return;
    }

    // otherwise, push the notification route
    navContext.push(location);
  }
}
