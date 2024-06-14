import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squad_quest/models/instance.dart';
import 'package:squad_quest/models/topic.dart';
import 'package:squad_quest/components/pickers/date.dart';
import 'package:squad_quest/components/pickers/time.dart';
import 'package:squad_quest/components/pickers/visibility.dart';
import 'package:squad_quest/components/pickers/topic.dart';
import 'package:squad_quest/controllers/instances.dart';

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

class PostEventScreen extends ConsumerStatefulWidget {
  const PostEventScreen({super.key});

  @override
  ConsumerState<PostEventScreen> createState() => _PostEventScreenState();
}

class _PostEventScreenState extends ConsumerState<PostEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationDescriptionController = TextEditingController();
  final _topicProvider = StateProvider<Topic?>((ref) => null);
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
          title: _titleController.text.trim(),
          topic: ref.read(_topicProvider),
          startTimeMin: startDateTimeMin,
          startTimeMax: startDateTimeMax,
          visibility: visibility,
          locationDescription: _locationDescriptionController.text.trim());

      final Instance savedInstance =
          await instancesController.createInstance(draftInstance);

      log('Saved instance: $savedInstance');
    } catch (error) {
      log('Error saving instance : $error');

      setState(() {
        submitted = false;
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to post event:\n\n$error'),
      ));

      return;
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Event posted!'),
    ));

    context.go('/');
  }

  @override
  void initState() {
    super.initState();

    startDate = DateTime.now().add(const Duration(days: 1));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Post an event'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  autofocus: true,
                  readOnly: submitted,
                  textInputAction: TextInputAction.next,
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
                TextFormField(
                  readOnly: submitted,
                  textInputAction: TextInputAction.next,
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
                FormTopicPicker(valueProvider: _topicProvider),
                const SizedBox(
                  height: 24,
                ),
                FormDatePicker(
                    labelText: 'Date to meet up on',
                    initialValue: startDate,
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
                        onPressed:
                            submitted ? null : () => _submitEvent(context),
                        child: const Text(
                          'Post',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
