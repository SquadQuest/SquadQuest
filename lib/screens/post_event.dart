import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/models/instance.dart';
import 'package:squad_quest/models/topic.dart';
import 'package:squad_quest/components/pickers/date.dart';
import 'package:squad_quest/components/pickers/time.dart';
import 'package:squad_quest/components/pickers/visibility.dart';
import 'package:squad_quest/components/pickers/topic.dart';

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

  void _submitEvent(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // setState(() {
    //   submitted = true;
    // });

    try {
      var data = {
        'title': _titleController.text.trim(),
        'topic': ref.read(_topicProvider)?.name,
        'start_date': startDate,
        'start_time_min': ref.read(_startTimeMinProvider),
        'start_time_max': ref.read(_startTimeMaxProvider),
        'visibility': ref.read(_visibilityProvider),
      };

      log('Build data: $data');
      // await ref.read(authControllerProvider.notifier).updateProfile({
      //   'first_name': _firstNameController.text.trim(),
      //   'last_name': _lastNameController.text.trim(),
      //   'profile_initialized': true,
      // });
    } catch (error) {
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

    // context.go('/');
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
        body: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  readOnly: submitted,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    // prefixIcon: Icon(Icons.banner),
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
                FormDatePicker(
                    labelText: 'Date to meet up on',
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
                    ? const CircularProgressIndicator()
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
