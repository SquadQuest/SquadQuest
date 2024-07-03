import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/components/pickers/location.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/components/pickers/date.dart';
import 'package:squadquest/components/pickers/time.dart';
import 'package:squadquest/components/pickers/visibility.dart';
import 'package:squadquest/components/pickers/topic.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/router.dart';

TimeOfDay _plusMinutes(TimeOfDay timeOfDay, int minutes) {
  if (minutes == 0) {
    return timeOfDay;
  } else {
    int mofd = timeOfDay.hour * 60 + timeOfDay.minute;
    int newMofd = ((minutes % 1440) + mofd + 1440) % 1440;
    if (mofd == newMofd) {
      return timeOfDay;
    } else {
      int newHour = newMofd ~/ 60;
      int newMinute = newMofd % 60;
      return TimeOfDay(hour: newHour, minute: newMinute);
    }
  }
}

class EventEditScreen extends ConsumerStatefulWidget {
  final InstanceID? instanceId;

  const EventEditScreen({super.key, this.instanceId});

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  late AsyncValue<Instance?> _editingInstance;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationDescriptionController = TextEditingController();
  final _topicProvider = StateProvider<Topic?>((ref) => null);
  final _locationProvider = StateProvider<Geographic?>((ref) => null);
  final _startTimeMinProvider =
      StateProvider<TimeOfDay?>((ref) => _plusMinutes(TimeOfDay.now(), 60));
  final _startTimeMaxProvider =
      StateProvider<TimeOfDay?>((ref) => _plusMinutes(TimeOfDay.now(), 75));
  final _visibilityProvider =
      StateProvider<InstanceVisibility?>((ref) => InstanceVisibility.friends);

  DateTime? startDate;
  bool startTimeMaxSet = false;
  bool submitted = false;

  void _showValidationError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Your event isn\'t ready to post:\n\n$error'),
    ));
  }

  void _submitEvent(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final TimeOfDay? startTimeMin = ref.read(_startTimeMinProvider);
    final TimeOfDay? startTimeMax = ref.read(_startTimeMaxProvider);
    final InstanceVisibility? visibility = ref.read(_visibilityProvider);
    final Geographic? rallyPoint = ref.read(_locationProvider);

    // Apply validation rules
    if (startDate == null) {
      return _showValidationError('Please select a date for the event');
    }

    if (startTimeMin == null) {
      return _showValidationError(
          'Please select an earliest start time for the event');
    }

    if (startTimeMax == null) {
      return _showValidationError(
          'Please select a latest start time for the event');
    }

    final startDateTimeMin = DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day,
      startTimeMin.hour,
      startTimeMin.minute,
    );

    final startDateTimeMax = DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day,
      startTimeMax.hour,
      startTimeMax.minute,
    );

    if (startDateTimeMax.isBefore(startDateTimeMin)) {
      return _showValidationError(
          'Latest start time must be after earliest start time');
    }

    if (visibility == null) {
      return _showValidationError('Please select a visibility for the event');
    }

    setState(() {
      submitted = true;
    });

    try {
      final instancesController = ref.read(instancesProvider.notifier);

      final Instance draftInstance = Instance(
          id: _editingInstance.value?.id,
          createdAt: _editingInstance.value?.createdAt,
          createdBy: _editingInstance.value?.createdBy,
          title: _titleController.text.trim(),
          topic: ref.read(_topicProvider),
          startTimeMin: startDateTimeMin,
          startTimeMax: startDateTimeMax,
          visibility: visibility,
          locationDescription: _locationDescriptionController.text.trim(),
          rallyPoint: rallyPoint);

      final Instance savedInstance =
          await instancesController.save(draftInstance);

      log('Saved instance: $savedInstance');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Event posted!'),
      ));

      final router = ref.read(routerProvider);
      final routeMatches = router.routerDelegate.currentConfiguration.matches;
      final previousRoute = routeMatches.length > 1
          ? routeMatches[routeMatches.length - 2]
          : null;

      // if previous screen is details for this event, just pop it back
      if (previousRoute != null &&
          previousRoute.matchedLocation == '/events/${savedInstance.id}') {
        context.pop();
      } else {
        context.pushReplacementNamed('event-details',
            pathParameters: {'id': savedInstance.id!});
      }
    } catch (error) {
      log('Error saving instance : $error');

      setState(() {
        submitted = false;
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to post event:\n\n$error'),
      ));
    }
  }

  @override
  void initState() {
    super.initState();

    startDate = DateTime.now();

    if (widget.instanceId == null) {
      _editingInstance = const AsyncValue.data(null);
    } else {
      _editingInstance = const AsyncValue.loading();
      final instancesController = ref.read(instancesProvider.notifier);
      AsyncValue.guard(() => instancesController.getById(widget.instanceId!))
          .then((instanceAsync) {
        setState(() {
          // pre-populate form controllers
          final instance = instanceAsync.value!;
          _titleController.text = instance.title;
          _locationDescriptionController.text = instance.locationDescription;
          ref.read(_topicProvider.notifier).state = instance.topic;
          ref.read(_locationProvider.notifier).state = instance.rallyPoint;
          startDate = instance.startTimeMin;
          ref.read(_startTimeMinProvider.notifier).state =
              TimeOfDay.fromDateTime(instance.startTimeMin);
          ref.read(_startTimeMaxProvider.notifier).state =
              TimeOfDay.fromDateTime(instance.startTimeMax);
          ref.read(_visibilityProvider.notifier).state = instance.visibility;

          // apply AsyncValue to state
          _editingInstance = instanceAsync;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _editingInstance.when(
        data: (Instance? instance) =>
            instance == null ? 'Post an event' : 'Edit event',
        loading: () => '',
        error: (_, __) => 'Error loading event',
      ),
      showDrawer: false,
      showLocationSharingSheet: false,
      bodyPadding: const EdgeInsets.all(16),
      body: _editingInstance.when(
          error: (error, __) => Center(child: Text(error.toString())),
          loading: () => const Center(child: CircularProgressIndicator()),
          data: (Instance? instance) => SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        autofocus: instance == null,
                        readOnly: submitted,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          // prefixIcon: Icon(Icons.flag),
                          labelText: 'Title for event',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter event title';
                          }
                          return null;
                        },
                        controller: _titleController,
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                      FormTopicPicker(valueProvider: _topicProvider),
                      const SizedBox(
                        height: 24,
                      ),
                      TextFormField(
                        readOnly: submitted,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          // prefixIcon: Icon(Icons.pin_drop),
                          labelText: 'Description of location',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter location descrption';
                          }
                          return null;
                        },
                        controller: _locationDescriptionController,
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                      FormLocationPicker(valueProvider: _locationProvider),
                      const SizedBox(
                        height: 24,
                      ),
                      FormDatePicker(
                          labelText: 'Date to meet up on',
                          initialValue: startDate,
                          firstDate: instance == null ||
                                  instance.startTimeMax.isAfter(DateTime.now())
                              ? null
                              : instance.startTimeMin,
                          onChanged: (DateTime date) {
                            setState(() {
                              startDate = date;
                            });
                          }),
                      const SizedBox(height: 16),
                      FormTimePicker(
                          labelText: 'Earliest time to meet up at',
                          valueProvider: _startTimeMinProvider,
                          onChanged: (TimeOfDay time) {
                            if (!startTimeMaxSet) {
                              ref.read(_startTimeMaxProvider.notifier).state =
                                  _plusMinutes(time, 15);
                            }
                          }),
                      const SizedBox(height: 16),
                      FormTimePicker(
                          labelText: 'Latest time to meet up by',
                          valueProvider: _startTimeMaxProvider,
                          onChanged: (TimeOfDay time) {
                            setState(() {
                              startTimeMaxSet = true;
                            });
                          }),
                      const SizedBox(height: 16),
                      FormVisibilityPicker(
                          labelText: 'Visibility of this posting',
                          valueProvider: _visibilityProvider),
                      const SizedBox(height: 16),
                      submitted
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: submitted
                                  ? null
                                  : () => _submitEvent(context),
                              child: Text(
                                instance == null ? 'Post' : 'Save Changes',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            )
                    ],
                  ),
                ),
              )),
    );
  }
}
