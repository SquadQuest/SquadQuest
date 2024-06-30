import 'package:flutter/material.dart';

import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/models/instance.dart';

class InstanceTile extends ListTile {
  final Instance instance;
  final InstanceMember? rsvp;

  InstanceTile({super.key, super.onTap, required this.instance, this.rsvp})
      : super(
          leading: statusIcons[instance.status] ??
              visibilityIcons[instance.visibility],
          title: Text(
            instance.title,
            style: TextStyle(
              decoration: instance.status == InstanceStatus.canceled
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (instance.status == InstanceStatus.canceled) ...[
                const Text('Status: CANCELED')
              ],
              Text('Location: ${instance.locationDescription}'),
              Text('Topic: ${instance.topic?.name}'),
              Text(
                  'Posted by: ${instance.createdBy?.firstName} ${instance.createdBy?.lastName}'),
              Text('Date: ${eventDateFormat.format(instance.startTimeMin)}'),
              Text(
                  'Starting between: ${eventTimeFormat.format(instance.startTimeMin)}–${eventTimeFormat.format(instance.startTimeMax)}'),
            ],
          ),
          trailing: rsvp == null ? null : rsvpIcons[rsvp.status],
        );
}
