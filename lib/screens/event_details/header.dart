import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:squadquest/models/instance.dart';

final eventDateFormat = DateFormat('EEEE, MMMM d');
final eventTimeFormat = DateFormat('h:mm a');

class EventDetailsHeader extends StatelessWidget {
  final Instance event;

  const EventDetailsHeader({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event.status == InstanceStatus.canceled)
          const ListTile(
            contentPadding: EdgeInsets.only(bottom: 16),
            minVerticalPadding: 3,
            minTileHeight: 0,
            leading: Icon(Icons.cancel_outlined),
            textColor: Colors.red,
            iconColor: Colors.red,
            title: Text('THIS EVENT HAS BEEN CANCELED'),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 3,
          minTileHeight: 0,
          leading: visibilityIcons[event.visibility],
          title: switch (event.visibility) {
            InstanceVisibility.private => const Text('Private event'),
            InstanceVisibility.friends => const Text('Friends-only event'),
            InstanceVisibility.public => const Text('Public event'),
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 3,
          minTileHeight: 0,
          leading: const Icon(Icons.today),
          title: Text(eventDateFormat.format(event.startTimeMin)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 3,
          minTileHeight: 0,
          leading: const Icon(Icons.timelapse),
          title: Text(
              '${eventTimeFormat.format(event.startTimeMin)}–${eventTimeFormat.format(event.startTimeMax)}'),
          subtitle: const Text('Meet up between'),
        ),
        if (event.topic != null) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: 3,
            minTileHeight: 0,
            leading: const Icon(Icons.topic),
            title: Text(event.topic!.name),
          ),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 3,
          minTileHeight: 0,
          leading: const Icon(Icons.person_pin),
          title: Text(event.createdBy!.displayName),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 3,
          minTileHeight: 0,
          leading: const Icon(Icons.place),
          trailing: const Icon(Icons.open_in_new),
          title: Text(event.locationDescription),
          onTap: () {
            final query = event.rallyPointPlusCode ?? event.locationDescription;
            final uri = Platform.isIOS
                ? Uri(
                    scheme: 'comgooglemaps',
                    host: '',
                    queryParameters: {'q': query})
                : Uri(
                    scheme: 'https',
                    host: 'maps.google.com',
                    queryParameters: {'q': query});
            launchUrl(uri);
          },
        ),
        if (event.link != null) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: 3,
            minTileHeight: 0,
            leading: const Icon(Icons.link),
            trailing: const Icon(Icons.open_in_new),
            title: Text(
              event.link.toString(),
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => launchUrl(event.link!),
          ),
        ],
        if (event.notes != null && event.notes!.trim().isNotEmpty) ...[
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(event.notes!)),
        ],
      ],
    );
  }
}
