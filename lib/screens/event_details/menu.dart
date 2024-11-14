import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/screens/chat.dart';

enum Menu {
  showSetRallyPointMap,
  showLiveMap,
  showChat,
  getLink,
  edit,
  cancel,
  uncancel,
  duplicate
}

class EventDetailsMenu extends ConsumerWidget {
  final Instance event;
  final InstanceID instanceId;
  final UserID? currentUserId;
  final InstanceMemberStatus? myRsvpStatus;
  final Function() onShowRallyPointMap;
  final Function() onShowLiveMap;

  const EventDetailsMenu({
    super.key,
    required this.event,
    required this.instanceId,
    required this.currentUserId,
    required this.myRsvpStatus,
    required this.onShowRallyPointMap,
    required this.onShowLiveMap,
  });

  Future<void> _cancelEvent(BuildContext context, WidgetRef ref,
      [bool canceled = true]) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              title: Text('${canceled ? 'Cancel' : 'Uncancel'} event?'),
              content: Text(
                  'Are you sure you want to ${canceled ? 'cancel' : 'uncancel'} this event? Guests will be alerted.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            ));

    if (confirmed != true) {
      return;
    }

    await ref
        .read(instancesProvider.notifier)
        .patch(instanceId, {'status': canceled ? 'canceled' : 'live'});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Your event has been ${canceled ? 'canceled' : 'uncanceled'} and guests will be alerted'),
      ));
    }
  }

  void _onMenuSelect(Menu item, BuildContext context, WidgetRef ref) async {
    switch (item) {
      case Menu.showSetRallyPointMap:
        onShowRallyPointMap();
        break;
      case Menu.showLiveMap:
        onShowLiveMap();
        break;
      case Menu.showChat:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => ChatScreen(
              instanceId: instanceId,
              autofocus: true,
            ),
          ),
        );
        break;
      case Menu.getLink:
        await Clipboard.setData(
            ClipboardData(text: "https://squadquest.app/events/$instanceId"));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Event link copied to clipboard'),
          ));
        }
        break;
      case Menu.edit:
        context.pushNamed('event-edit', pathParameters: {
          'id': instanceId,
        });
        break;
      case Menu.cancel:
        await _cancelEvent(context, ref);
        break;
      case Menu.uncancel:
        await _cancelEvent(context, ref, false);
        break;
      case Menu.duplicate:
        context.pushNamed('post-event', queryParameters: {
          'duplicateEventId': instanceId,
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<Menu>(
      icon: const Icon(Icons.more_vert),
      offset: const Offset(0, 50),
      onSelected: (item) => _onMenuSelect(item, context, ref),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<Menu>>[
        const PopupMenuItem<Menu>(
          value: Menu.showLiveMap,
          child: ListTile(
            leading: Icon(Icons.map),
            title: Text('Open live map'),
          ),
        ),
        if (myRsvpStatus != null)
          const PopupMenuItem<Menu>(
            value: Menu.showChat,
            child: ListTile(
              leading: Icon(Icons.chat),
              title: Text('Open chat'),
            ),
          ),
        const PopupMenuItem<Menu>(
          value: Menu.getLink,
          child: ListTile(
            leading: Icon(Icons.link_outlined),
            title: Text('Get link'),
          ),
        ),
        if (event.createdById == currentUserId) ...[
          const PopupMenuDivider(),
          PopupMenuItem<Menu>(
            value: Menu.showSetRallyPointMap,
            child: ListTile(
              leading: const Icon(Icons.pin_drop_outlined),
              title: event.rallyPoint == null
                  ? const Text('Set rally point')
                  : const Text('Update rally point'),
            ),
          ),
          const PopupMenuItem<Menu>(
            value: Menu.edit,
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit event'),
            ),
          ),
          PopupMenuItem<Menu>(
            value: event.status == InstanceStatus.canceled
                ? Menu.uncancel
                : Menu.cancel,
            child: ListTile(
              leading: const Icon(Icons.cancel),
              title: event.status == InstanceStatus.canceled
                  ? const Text('Uncancel event')
                  : const Text('Cancel event'),
            ),
          ),
          const PopupMenuItem<Menu>(
            value: Menu.duplicate,
            child: ListTile(
              leading: Icon(Icons.copy),
              title: Text('Duplicate event'),
            ),
          ),
        ]
      ],
    );
  }
}
