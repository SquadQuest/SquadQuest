import 'package:flutter/material.dart';

import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/models/instance.dart';

class InstanceTile extends ListTile {
  final Instance instance;
  final InstanceMember? rsvp;

  InstanceTile({super.key, super.onTap, required this.instance, this.rsvp})
      : super(
          leading: visibilityIcons[instance.visibility],
          title: Text(instance.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
