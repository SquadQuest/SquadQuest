import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/router.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/components/pickers/location.dart';
import 'package:squadquest/components/pickers/photo.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/components/pickers/date.dart';
import 'package:squadquest/components/pickers/time.dart';
import 'package:squadquest/components/pickers/visibility.dart';
import 'package:squadquest/components/pickers/topic.dart';
import 'package:squadquest/controllers/instances.dart';

enum AutoFocusField { title, topic }

final _urlRegex = RegExp(r'^https?://', caseSensitive: false);

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
  final String? facebookUrl;
  final InstanceID? duplicateEventId;

  const EventEditScreen(
      {super.key, this.instanceId, this.facebookUrl, this.duplicateEventId})
      : assert(duplicateEventId == null || facebookUrl == null,
            'duplicateEventId and facebookUrl cannot both be provided'),
        assert(instanceId == null || facebookUrl == null,
            'instanceId and facebookUrl cannot both be provided'),
        assert(instanceId == null || duplicateEventId == null,
            'instanceId and duplicateEventId cannot both be provided');

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  String? loadMask;
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
  final _notesController = TextEditingController();
  final _linkController = TextEditingController();
  final _bannerPhotoProvider = StateProvider<Uri?>((ref) => null);

  DateTime? startDate;
  bool startTimeMaxSet = false;
  bool submitted = false;
  late final bool isNewEvent;
  late final AutoFocusField? autoFocusField;

  void _showValidationError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Your event isn\'t ready to post:\n\n$error'),
    ));
  }

  void _submitEvent(BuildContext context) async {
    FocusScope.of(context).unfocus();

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

    // upload photo
    final supabase = ref.read(supabaseClientProvider);
    final bannerPhoto = ref.read(_bannerPhotoProvider);

    String? tempBannerPhotoPath;

    if (bannerPhoto != null && !bannerPhoto.isScheme('https')) {
      try {
        tempBannerPhotoPath = '_pending/${supabase.auth.currentUser!.id}';
        await uploadPhoto(
            bannerPhoto, tempBannerPhotoPath, supabase, 'event-banners');
      } catch (error) {
        log('Error uploading banner photo: $error');

        setState(() {
          submitted = false;
        });

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to upload banner photo:\n\n$error'),
        ));

        return;
      }
    }

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
          rallyPoint: rallyPoint,
          link: _linkController.text.trim().isNotEmpty
              ? Uri.parse(_linkController.text.trim())
              : null,
          notes: _notesController.text.trim(),
          bannerPhoto: tempBannerPhotoPath == null ? bannerPhoto : null);

      final Instance savedInstance =
          await instancesController.save(draftInstance);

      log('Saved instance: $savedInstance');

      if (tempBannerPhotoPath != null) {
        final bannerPhotoUrl = await movePhoto(
            tempBannerPhotoPath, savedInstance.id!, supabase, 'event-banners',
            upsert: true,
            transform: const TransformOptions(width: 1024, height: 1024));
        await instancesController.patch(
            savedInstance.id!, {'banner_photo': bannerPhotoUrl.toString()});
        log('Moved banner photo');
      }

      ref.invalidate(eventDetailsProvider(savedInstance.id!));

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_editingInstance.value == null
            ? 'Event posted!'
            : 'Event updated!'),
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
      log('Error saving instance: $error');

      setState(() {
        submitted = false;
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to post event:\n\n$error'),
      ));
    }
  }

  void _loadValuesFromInstance(Instance instance) {
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
    _linkController.text = instance.link?.toString() ?? '';
    _notesController.text = instance.notes?.toString() ?? '';
    ref.read(_bannerPhotoProvider.notifier).state = instance.bannerPhoto;
  }

  @override
  void initState() {
    super.initState();

    startDate = DateTime.now();

    final instancesController = ref.read(instancesProvider.notifier);

    // load an existing event for editing
    if (widget.instanceId != null) {
      isNewEvent = false;
      autoFocusField = null;
      loadMask = 'Loading event...';
      _editingInstance = const AsyncValue.loading();

      instancesController.getById(widget.instanceId!).then((instance) {
        setState(() {
          // pre-populate form controllers
          _loadValuesFromInstance(instance);

          // apply AsyncValue to state
          _editingInstance = AsyncValue.data(instance);

          // clear mask
          loadMask = null;
        });
      }).onError((error, stackTrace) {
        logger.e('Error loading event to edit',
            error: error, stackTrace: stackTrace);

        context.pop();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load event to edit:\n\n$error'),
        ));

        return;
      });

      return;
    }

    // load an existing event for duplicating
    if (widget.duplicateEventId != null) {
      isNewEvent = true;
      autoFocusField = null;
      loadMask = 'Loading event...';
      _editingInstance = const AsyncValue.loading();

      instancesController.getById(widget.duplicateEventId!).then((instance) {
        setState(() {
          // pre-populate form controllers
          _loadValuesFromInstance(instance);

          // clear date
          startDate = null;

          // apply AsyncValue to state
          _editingInstance = const AsyncValue.data(null);

          // clear mask
          loadMask = null;
        });
      }).onError((error, stackTrace) {
        logger.e('Error loading event to duplicate',
            error: error, stackTrace: stackTrace);

        context.pop();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load event to duplicate:\n\n$error'),
        ));

        return;
      });

      return;
    }

    // populate a new event from Facebook event data
    if (widget.facebookUrl != null) {
      isNewEvent = true;
      autoFocusField = AutoFocusField.topic;
      loadMask = 'Loading Facebook event...';
      _editingInstance = const AsyncValue.loading();

      instancesController
          .fetchFacebookEventData(widget.facebookUrl!)
          .then((instance) {
        logger.d({'loaded FB instance': instance});
        setState(() {
          // pre-populate form controllers
          _loadValuesFromInstance(instance);

          // apply AsyncValue to state
          _editingInstance = const AsyncValue.data(null);

          // clear mask
          loadMask = null;
        });
      }).onError((error, stackTrace) {
        logger.e('Error loading Facebook event',
            error: error, stackTrace: stackTrace);

        context.pop();

        final message = error is FunctionException
            ? (error.details?['message'] ?? error.details)
            : error;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load Facebook event:\n\n$message'),
        ));

        return;
      });

      return;
    }

    // default: create a new event from scratch
    isNewEvent = true;
    autoFocusField = AutoFocusField.title;
    _editingInstance = const AsyncValue.data(null);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _editingInstance.when(
        data: (Instance? instance) =>
            isNewEvent ? 'Post an event' : 'Edit event',
        loading: () => '',
        error: (_, __) => 'Error loading event',
      ),
      loadMask: submitted
          ? isNewEvent
              ? 'Posting event...'
              : 'Saving event...'
          : loadMask,
      actions: [
        if (!submitted && !_editingInstance.isLoading && loadMask == null)
          TextButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () => _submitEvent(context),
            child: Text(isNewEvent ? 'Post' : 'Save',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
      ],
      showLocationSharingSheet: false,
      body: _editingInstance.when(
          error: (error, __) => Center(child: Text(error.toString())),
          loading: () => const SizedBox.shrink(),
          data: (Instance? instance) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        autofocus: autoFocusField == AutoFocusField.title,
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
                      FormTopicPicker(valueProvider: _topicProvider),
                      const SizedBox(
                        height: 24,
                      ),
                      FormDatePicker(
                          labelText: 'Date to meet up on',
                          initialValue: startDate,
                          firstDate: isNewEvent ||
                                  instance!.startTimeMax.isAfter(DateTime.now())
                              ? null
                              : instance.startTimeMin,
                          onChanged: (DateTime date) {
                            setState(() {
                              startDate = date;
                            });
                          }),
                      FormTimePicker(
                          labelText: 'Earliest time to meet up at',
                          valueProvider: _startTimeMinProvider,
                          onChanged: (TimeOfDay time) {
                            if (!startTimeMaxSet) {
                              ref.read(_startTimeMaxProvider.notifier).state =
                                  _plusMinutes(time, 15);
                            }
                          }),
                      FormTimePicker(
                          labelText: 'Latest time to meet up by',
                          valueProvider: _startTimeMaxProvider,
                          onChanged: (TimeOfDay time) {
                            setState(() {
                              startTimeMaxSet = true;
                            });
                          }),
                      const SizedBox(
                        height: 24,
                      ),
                      FormLocationPicker(
                          valueProvider: _locationProvider,
                          onPlaceSelect: (placeName) {
                            if (_locationDescriptionController.text.isEmpty) {
                              _locationDescriptionController.text = placeName;
                            }
                          }),
                      TextFormField(
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
                      const SizedBox(height: 24),
                      FormVisibilityPicker(
                          labelText: 'Visibility of this posting',
                          valueProvider: _visibilityProvider),
                      const SizedBox(
                        height: 24,
                      ),
                      TextFormField(
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.url],
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Event link (optional)',
                        ),
                        controller: _linkController,
                        validator: (value) {
                          if (value != null &&
                              value.isNotEmpty &&
                              !_urlRegex.hasMatch(value)) {
                            return 'Link must start with http:// or https://';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        // textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          labelText: 'Event notes (optional)',
                        ),
                        maxLines: 5,
                        controller: _notesController,
                      ),
                      const SizedBox(height: 32),
                      FormPhotoPicker(
                          labelText: 'Event banner photo',
                          valueProvider: _bannerPhotoProvider)
                    ],
                  ),
                ),
              )),
    );
  }
}
