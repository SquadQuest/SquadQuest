import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/router.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/controllers/location.dart';
import 'package:squadquest/controllers/calendar.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/app.dart';

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return NotificationsService(ref);
});

class NotificationsService {
  final Ref ref;

  NotificationsService(this.ref) {
    _init();
  }

  void _init() {
    log('Initializing notifications...');

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
            case 'invitation':
              if (ref.read(calendarWritingEnabledProvider)) {
                final instance = Instance.fromMap(data['event']);
                final subscription = InstanceMember.fromMap(data['invitation']);

                CalendarController.instance.upsertEvent(
                  instance: instance,
                  subscription: subscription,
                );
              }
          }
          // Display push notification in-app
          scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
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
            case 'event-message':
            case 'rally-point-updated':
            case 'rsvp':
              _goToNotificationRoute('/events/${data['event']['id']}');
            case 'invitation':
              // Write to calendar when invitation notification is opened
              if (ref.read(calendarWritingEnabledProvider)) {
                final instance = Instance.fromMap(data['event']);
                final subscription = InstanceMember.fromMap(data['invitation']);

                CalendarController.instance.upsertEvent(
                  instance: instance,
                  subscription: subscription,
                );
              }
              _goToNotificationRoute(
                  '/events/${data['invitation']['instance']}');
            case 'friend-request-received':
            case 'friend-request-accepted':
              _goToNotificationRoute('/friends');
          }
      }
    });
  }

  void _goToNotificationRoute(String location) {
    logger.t({
      'goToNotificationRoute': {'location': location}
    });

    ref.read(routerProvider).router.push(location);
  }
}
