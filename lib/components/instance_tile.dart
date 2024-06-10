import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:squad_quest/models/instance.dart';

final _dateFormat = DateFormat('E, MMM d');
final _timeFormat = DateFormat('h:mm a');

class InstanceTile extends ListTile {
  final Instance instance;

  InstanceTile({super.key, required this.instance})
      : super(
            leading: switch (instance.visibility) {
              InstanceVisibility.public => const Icon(Icons.public),
              InstanceVisibility.private => const Icon(Icons.lock),
              InstanceVisibility.friends => const Icon(Icons.people),
            },
            title: Text(instance.title),
            subtitle: Text(
                'Topic: ${instance.topic?.name}\nPosted by: ${instance.createdBy?.firstName} ${instance.createdBy?.lastName}\nDate: ${_dateFormat.format(instance.startTimeMin)}\nStarting between: ${_timeFormat.format(instance.startTimeMin)}–${_timeFormat.format(instance.startTimeMax)}'));
}
