import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/models/user.dart';

class NotificationOptions extends ConsumerStatefulWidget {
  const NotificationOptions({super.key});

  @override
  ConsumerState<NotificationOptions> createState() =>
      _NotificationOptionsState();
}

class _NotificationOptionsState extends ConsumerState<NotificationOptions> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final profileController = ref.read(profileProvider.notifier);

    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Friend Requests'),
          subtitle: const Text(
              'When someone who already knows your phone number requests to be your friend on SquadQuest'),
          value: profile.value?.enabledNotifications
                  .contains(NotificationType.friendRequest) ??
              false,
          onChanged: (bool? enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.friendRequest, enabled!);
          },
          secondary: const Icon(Icons.people),
        ),
        CheckboxListTile(
          title: const Text('Event Invitations'),
          subtitle: const Text('When a friend invites you to an event'),
          value: profile.value?.enabledNotifications
                  .contains(NotificationType.eventInvitation) ??
              false,
          onChanged: (bool? enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.eventInvitation, enabled!);
          },
          secondary: const Icon(Icons.mail),
        ),
        CheckboxListTile(
          title: const Text('Event Changes'),
          subtitle: const Text(
              'When an event you\'ve RSVPd to has a key detail changed or is canceled'),
          value: profile.value?.enabledNotifications
                  .contains(NotificationType.eventChange) ??
              false,
          onChanged: (bool? enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.eventChange, enabled!);
          },
          secondary: const Icon(Icons.edit_calendar),
        ),
        CheckboxListTile(
          title: const Text('New Friends Event'),
          subtitle: const Text(
              'When a new friends-only event is posted by one of your friends to a topic you subscribe to'),
          value: profile.value?.enabledNotifications
                  .contains(NotificationType.friendsEventPosted) ??
              false,
          onChanged: (bool? enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.friendsEventPosted, enabled!);
          },
          secondary: const Icon(Icons.event),
        ),
        CheckboxListTile(
          title: const Text('New Public Event'),
          subtitle: const Text(
              'When a new public event is posted to a topic you subscribe to'),
          value: profile.value?.enabledNotifications
                  .contains(NotificationType.publicEventPosted) ??
              false,
          onChanged: (bool? enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.publicEventPosted, enabled!);
          },
          secondary: const Icon(Icons.event),
        ),
        CheckboxListTile(
          title: const Text('Guest RSVPs'),
          subtitle: const Text(
              'When someone changes their RSVP status to an event you posted'),
          value: profile.value?.enabledNotifications
                  .contains(NotificationType.guestRsvp) ??
              false,
          onChanged: (bool? enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.guestRsvp, enabled!);
          },
          secondary: const Icon(Icons.mail),
        ),
        CheckboxListTile(
          title: const Text('Friends OMW'),
          subtitle: const Text(
              'When a friend is on their way to an event you RSVPd to'),
          value: profile.value?.enabledNotifications
                  .contains(NotificationType.friendOnTheWay) ??
              false,
          onChanged: (bool? enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.friendOnTheWay, enabled!);
          },
          secondary: const Icon(Icons.run_circle_outlined),
        ),
        CheckboxListTile(
          title: const Text('Event Chat'),
          subtitle: const Text(
              'When a message gets posted to chat in an event you RSVPd to'),
          value: profile.value?.enabledNotifications
                  .contains(NotificationType.eventMessage) ??
              false,
          onChanged: (bool? enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.eventMessage, enabled!);
          },
          secondary: const Icon(Icons.message),
        ),
      ],
    );
  }
}
