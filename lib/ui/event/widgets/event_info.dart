import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';

import 'package:squadquest/models/instance.dart';

import 'event_section.dart';

class EventInfo extends StatefulWidget {
  final Instance event;

  const EventInfo({
    super.key,
    required this.event,
  });

  @override
  State<EventInfo> createState() => _EventInfoState();
}

class _EventInfoState extends State<EventInfo> {
  @override
  Widget build(BuildContext context) {
    return EventSection(
      title: 'Event Info',
      children: [
        _buildInfoRow(
          context,
          icon: Icons.person,
          label: 'Posted by',
          value: widget.event.createdBy!.displayName,
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          context,
          icon: Icons.schedule,
          label: 'Time',
          value:
              'Starts between ${DateFormat('h:mm a').format(widget.event.startTimeMin)}-${DateFormat('h:mm a').format(widget.event.startTimeMax)}',
          secondaryValue: widget.event.endTime != null
              ? 'Ends around ${DateFormat('h:mm a').format(widget.event.endTime!)}'
              : null,
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          context,
          icon: Icons.visibility,
          label: 'Visibility',
          value: switch (widget.event.visibility) {
            InstanceVisibility.private => 'Private event',
            InstanceVisibility.friends => 'Friends-only event',
            InstanceVisibility.public => 'Public event',
          },
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          context,
          icon: Icons.category,
          label: 'Topic',
          value: widget.event.topic?.name ?? '',
        ),
        if (widget.event.link != null) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              launchUrl(widget.event.link!);
            },
            child: _buildInfoRow(
              context,
              icon: Icons.link,
              trailingIcon: Icons.open_in_new,
              label: 'Link',
              value: widget.event.link.toString(),
            ),
          ),
        ],
        if (widget.event.rallyPoint != null) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final query = widget.event.rallyPoint == null
                  ? widget.event.locationDescription
                  : '${widget.event.rallyPoint!.lat},${widget.event.rallyPoint!.lon}';

              final googleMapsUri = Uri(
                scheme: 'https',
                host: 'maps.google.com',
                queryParameters: {
                  'daddr': query,
                  'q': widget.event.locationDescription,
                  'directionsmode': 'bicycling',
                },
              );

              final googleMapsIosUri = Uri(
                scheme: 'comgooglemaps',
                host: '',
                queryParameters: {
                  'daddr': query,
                  'q': widget.event.locationDescription,
                  'directionsmode': 'bicycling',
                },
              );

              final appleMapsUri = Uri(
                scheme: 'https',
                host: 'maps.apple.com',
                queryParameters: {
                  'daddr': query,
                  'dirflg': 'c',
                },
              );

              if (Platform.isIOS) {
                if (await canLaunchUrl(googleMapsIosUri)) {
                  await launchUrl(googleMapsIosUri);
                } else {
                  await launchUrl(appleMapsUri);
                }
              } else {
                await launchUrl(googleMapsUri);
              }
            },
            child: _buildInfoRow(context,
                icon: Icons.navigation_outlined,
                trailingIcon: Icons.open_in_new,
                label: 'Rally point',
                value: widget.event.locationDescription,
                secondaryValue:
                    'Coordinates: ${widget.event.rallyPointPlusCode}'),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    IconData? trailingIcon,
    String? secondaryValue,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (secondaryValue != null) ...[
                const SizedBox(height: 2),
                Text(
                  secondaryValue,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 16),
          Icon(
            trailingIcon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        ],
      ],
    );
  }
}
