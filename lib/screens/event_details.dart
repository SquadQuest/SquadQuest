import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/controllers/instances.dart';
import 'package:squad_quest/models/instance.dart';

class EventDetailsScreen extends ConsumerStatefulWidget {
  final InstanceID id;

  const EventDetailsScreen({super.key, required this.id});

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  Instance? instance;

  @override
  void initState() {
    super.initState();

    ref
        .read(instancesProvider.notifier)
        .getById(widget.id)
        .then((Instance instance) {
      setState(() {
        this.instance = instance;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: instance == null
            ? null
            : AppBar(
                title: Text(instance!.title),
              ),
        body: instance == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Event Details Screen for ${instance!.title}'),
                      Text('Location: ${instance!.locationDescription}'),
                      Text('Topic: ${instance!.topic?.name}'),
                      Text('Posted by: ${instance!.createdBy?.fullName}'),
                      Text(
                          'Date: ${eventDateFormat.format(instance!.startTimeMin)}'),
                      Text(
                          'Starting between: ${eventTimeFormat.format(instance!.startTimeMin)}–${eventTimeFormat.format(instance!.startTimeMax)}')
                    ])),
      ),
    );
  }
}
