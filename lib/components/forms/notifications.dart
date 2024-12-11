import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/models/user.dart';

class NotificationOptions extends ConsumerStatefulWidget {
  final bool showDetails;

  const NotificationOptions({
    super.key,
    this.showDetails = false,
  });

  @override
  ConsumerState<NotificationOptions> createState() =>
      _NotificationOptionsState();
}

class _NotificationOptionsState extends ConsumerState<NotificationOptions> {
  Widget _buildNotificationTile({
    required NotificationType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool enabled,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: widget.showDetails ? Text(subtitle) : null,
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      trailing: Switch(
        value: enabled,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final profileController = ref.read(profileProvider.notifier);

    return Column(
      children: [
        _buildNotificationTile(
          type: NotificationType.friendRequest,
          title: 'Friend Requests',
          subtitle:
              'When someone who already knows your phone number requests to be your friend on SquadQuest',
          icon: Icons.person_add_outlined,
          enabled: profile.value?.enabledNotifications
                  .contains(NotificationType.friendRequest) ??
              false,
          onChanged: (enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.friendRequest, enabled);
          },
        ),
        _buildNotificationTile(
          type: NotificationType.eventInvitation,
          title: 'Event Invitations',
          subtitle: 'When a friend invites you to an event',
          icon: Icons.mail_outlined,
          enabled: profile.value?.enabledNotifications
                  .contains(NotificationType.eventInvitation) ??
              false,
          onChanged: (enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.eventInvitation, enabled);
          },
        ),
        _buildNotificationTile(
          type: NotificationType.eventChange,
          title: 'Event Changes',
          subtitle:
              'When an event you\'ve RSVPd to has a key detail changed or is canceled',
          icon: Icons.update_outlined,
          enabled: profile.value?.enabledNotifications
                  .contains(NotificationType.eventChange) ??
              false,
          onChanged: (enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.eventChange, enabled);
          },
        ),
        _buildNotificationTile(
          type: NotificationType.friendsEventPosted,
          title: 'New Friends Event',
          subtitle:
              'When a new friends-only event is posted by one of your friends to a topic you subscribe to',
          icon: Icons.group_outlined,
          enabled: profile.value?.enabledNotifications
                  .contains(NotificationType.friendsEventPosted) ??
              false,
          onChanged: (enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.friendsEventPosted, enabled);
          },
        ),
        _buildNotificationTile(
          type: NotificationType.publicEventPosted,
          title: 'New Public Event',
          subtitle:
              'When a new public event is posted to a topic you subscribe to',
          icon: Icons.event_available_outlined,
          enabled: profile.value?.enabledNotifications
                  .contains(NotificationType.publicEventPosted) ??
              false,
          onChanged: (enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.publicEventPosted, enabled);
          },
        ),
        _buildNotificationTile(
          type: NotificationType.guestRsvp,
          title: 'Guest RSVPs',
          subtitle:
              'When someone changes their RSVP status to an event you posted',
          icon: Icons.how_to_reg_outlined,
          enabled: profile.value?.enabledNotifications
                  .contains(NotificationType.guestRsvp) ??
              false,
          onChanged: (enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.guestRsvp, enabled);
          },
        ),
        _buildNotificationTile(
          type: NotificationType.friendOnTheWay,
          title: 'Friends OMW',
          subtitle: 'When a friend is on their way to an event you RSVPd to',
          icon: Icons.directions_run_outlined,
          enabled: profile.value?.enabledNotifications
                  .contains(NotificationType.friendOnTheWay) ??
              false,
          onChanged: (enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.friendOnTheWay, enabled);
          },
        ),
        _buildNotificationTile(
          type: NotificationType.eventMessage,
          title: 'Event Chat',
          subtitle:
              'When a message gets posted to chat in an event you RSVPd to',
          icon: Icons.chat_outlined,
          enabled: profile.value?.enabledNotifications
                  .contains(NotificationType.eventMessage) ??
              false,
          onChanged: (enabled) async {
            await profileController.setNotificationEnabled(
                NotificationType.eventMessage, enabled);
          },
        ),
      ],
    );
  }
}
