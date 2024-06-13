import 'package:flutter/material.dart';

import 'package:squad_quest/controllers/instances.dart';
import 'package:squad_quest/models/instance.dart';

class InstanceTile extends ListTile {
  final Instance instance;

  InstanceTile({super.key, super.onTap, required this.instance})
      : super(
            leading: visibilityIcons[instance.visibility],
            title: Text(instance.title),
            subtitle: Text(
                'Location: ${instance.locationDescription}\nTopic: ${instance.topic?.name}\nPosted by: ${instance.createdBy?.firstName} ${instance.createdBy?.lastName}\nDate: ${eventDateFormat.format(instance.startTimeMin)}\nStarting between: ${eventTimeFormat.format(instance.startTimeMin)}–${eventTimeFormat.format(instance.startTimeMax)}'));
}
