import 'dart:io';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/router.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/components/pickers/location.dart';
import 'package:squadquest/components/event_rally_map.dart';
import 'package:squadquest/components/map_preview.dart';
import 'package:squadquest/components/pickers/visibility.dart';
import 'package:squadquest/components/pickers/topic.dart';

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
  final _endTimeProvider = StateProvider<TimeOfDay?>((ref) => null);
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
    final TimeOfDay? endTime = ref.read(_endTimeProvider);
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

    // If max time is earlier than min time, assume it's the next day
    final startDateTimeMax = DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day + (startTimeMax.isBefore(startTimeMin) ? 1 : 0),
      startTimeMax.hour,
      startTimeMax.minute,
    );

    // If end time is earlier than min time or max time, assume it's the next day
    final endDateTime = endTime != null
        ? DateTime(
            startDate!.year,
            startDate!.month,
            startDate!.day +
                (endTime.isBefore(startTimeMin) ||
                        endTime.isBefore(startTimeMax)
                    ? 1
                    : 0),
            endTime.hour,
            endTime.minute,
          )
        : null;

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
          bannerPhoto: tempBannerPhotoPath == null ? bannerPhoto : null,
          endTime: endDateTime);

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

      final routeMatches = ref
          .read(routerProvider)
          .router
          .routerDelegate
          .currentConfiguration
          .matches;
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
    ref.read(_endTimeProvider.notifier).state = instance.endTime != null
        ? TimeOfDay.fromDateTime(instance.endTime!)
        : null;
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

        if (!mounted) return;

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

        if (!mounted) return;

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

        if (!mounted) return;

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
            isNewEvent ? 'Create Event' : 'Edit Event',
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
        data: (Instance? instance) => Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              // Banner Photo Section
              SliverToBoxAdapter(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final bannerPhoto = ref.watch(_bannerPhotoProvider);
                          if (bannerPhoto != null) {
                            return kIsWeb || !bannerPhoto.isScheme('file')
                                ? Image.network(
                                    bannerPhoto.toString(),
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(bannerPhoto.path),
                                    fit: BoxFit.cover,
                                  );
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.surfaceVariant,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Cover Photo',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final bannerPhoto = ref.watch(_bannerPhotoProvider);
                          if (bannerPhoto != null) {
                            return Positioned(
                              top: 8,
                              right: 8,
                              child: Row(
                                children: [
                                  IconButton.filledTonal(
                                    onPressed: () {
                                      ref
                                          .read(_bannerPhotoProvider.notifier)
                                          .state = null;
                                    },
                                    icon: const Icon(Icons.delete),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    onPressed: () async {
                                      final pickedFile = await ImagePicker()
                                          .pickImage(
                                              source: ImageSource.gallery);
                                      if (pickedFile != null) {
                                        ref
                                                .read(_bannerPhotoProvider.notifier)
                                                .state =
                                            kIsWeb
                                                ? Uri.parse(pickedFile.path)
                                                : File(pickedFile.path).uri;
                                      }
                                    },
                                    icon: const Icon(Icons.edit),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  final pickedFile = await ImagePicker()
                                      .pickImage(source: ImageSource.gallery);
                                  if (pickedFile != null) {
                                    ref
                                            .read(_bannerPhotoProvider.notifier)
                                            .state =
                                        kIsWeb
                                            ? Uri.parse(pickedFile.path)
                                            : File(pickedFile.path).uri;
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Form Content
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Basic Information',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                autofocus:
                                    autoFocusField == AutoFocusField.title,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Event Title',
                                  hintText: 'What\'s happening?',
                                  prefixIcon: const Icon(Icons.event),
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withAlpha(80),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter event title';
                                  }
                                  return null;
                                },
                                controller: _titleController,
                              ),
                              const SizedBox(height: 16),
                              FormTopicPicker(valueProvider: _topicProvider),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date & Time Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'When',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                leading: Icon(
                                  Icons.calendar_today,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: const Text('Date'),
                                subtitle: Text(
                                  startDate != null
                                      ? DateFormat.yMd().format(startDate!)
                                      : 'Select a date',
                                  style: startDate == null
                                      ? Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)
                                      : null,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Select',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  final newDate = await showDatePicker(
                                    context: context,
                                    initialDate: startDate ?? DateTime.now(),
                                    firstDate: isNewEvent ||
                                            instance?.startTimeMax
                                                    .isAfter(DateTime.now()) ==
                                                true
                                        ? DateTime.now()
                                        : instance!.startTimeMin,
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (newDate != null) {
                                    setState(() {
                                      startDate = newDate;
                                    });
                                  }
                                },
                              ),
                              const Divider(),
                              // Start Time Range
                              Card(
                                margin: EdgeInsets.zero,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 4),
                                      child: Text(
                                        'Start Time Range',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    Consumer(
                                      builder: (context, ref, _) {
                                        final startTimeMin =
                                            ref.watch(_startTimeMinProvider);
                                        return ListTile(
                                          leading: Icon(
                                            Icons.access_time,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          title: const Text('Earliest'),
                                          subtitle: Text(
                                            startTimeMin != null
                                                ? MaterialLocalizations.of(
                                                        context)
                                                    .formatTimeOfDay(
                                                        startTimeMin)
                                                : 'Select a time',
                                            style: startTimeMin == null
                                                ? Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant)
                                                : null,
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Select',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                              Icon(
                                                Icons.chevron_right,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ],
                                          ),
                                          onTap: () async {
                                            final newTime =
                                                await showTimePicker(
                                              context: context,
                                              initialTime: startTimeMin ??
                                                  TimeOfDay.now(),
                                            );
                                            if (newTime != null) {
                                              ref
                                                  .read(_startTimeMinProvider
                                                      .notifier)
                                                  .state = newTime;
                                              if (!startTimeMaxSet) {
                                                ref
                                                        .read(
                                                            _startTimeMaxProvider
                                                                .notifier)
                                                        .state =
                                                    _plusMinutes(newTime, 15);
                                              }
                                            }
                                          },
                                        );
                                      },
                                    ),
                                    Consumer(
                                      builder: (context, ref, _) {
                                        final startTimeMax =
                                            ref.watch(_startTimeMaxProvider);
                                        return ListTile(
                                          leading: Icon(
                                            Icons.access_time,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          title: const Text('Latest'),
                                          subtitle: Text(
                                            startTimeMax != null
                                                ? MaterialLocalizations.of(
                                                        context)
                                                    .formatTimeOfDay(
                                                        startTimeMax)
                                                : 'Select a time',
                                            style: startTimeMax == null
                                                ? Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant)
                                                : null,
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Select',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                              Icon(
                                                Icons.chevron_right,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ],
                                          ),
                                          onTap: () async {
                                            final newTime =
                                                await showTimePicker(
                                              context: context,
                                              initialTime: startTimeMax ??
                                                  TimeOfDay.now(),
                                            );
                                            if (newTime != null) {
                                              ref
                                                  .read(_startTimeMaxProvider
                                                      .notifier)
                                                  .state = newTime;
                                              setState(() {
                                                startTimeMaxSet = true;
                                              });
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 16),
                              // End Time (Optional)
                              Consumer(
                                builder: (context, ref, _) {
                                  final endTime = ref.watch(_endTimeProvider);
                                  return ListTile(
                                    leading: Icon(
                                      Icons.access_time,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    title: const Text('End Time'),
                                    subtitle: Text(
                                      endTime != null
                                          ? MaterialLocalizations.of(context)
                                              .formatTimeOfDay(endTime)
                                          : 'Optional',
                                      style: endTime == null
                                          ? Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant)
                                          : null,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (endTime != null)
                                          IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              ref
                                                  .read(
                                                      _endTimeProvider.notifier)
                                                  .state = null;
                                            },
                                          ),
                                        Text(
                                          'Select',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ],
                                    ),
                                    onTap: () async {
                                      final newTime = await showTimePicker(
                                        context: context,
                                        initialTime: endTime ?? TimeOfDay.now(),
                                      );
                                      if (newTime != null) {
                                        ref
                                            .read(_endTimeProvider.notifier)
                                            .state = newTime;
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Location Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Where',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withAlpha(80),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () async {
                                      Geographic? newValue =
                                          await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        enableDrag: false,
                                        isDismissible: false,
                                        builder: (BuildContext context) =>
                                            EventRallyMap(
                                          initialRallyPoint:
                                              ref.read(_locationProvider),
                                          onPlaceSelect: (placeName) {
                                            if (_locationDescriptionController
                                                .text.isEmpty) {
                                              _locationDescriptionController
                                                  .text = placeName;
                                            }
                                          },
                                        ),
                                      );

                                      if (newValue != null) {
                                        ref
                                            .read(_locationProvider.notifier)
                                            .state = newValue;
                                      }
                                    },
                                    child: Consumer(
                                      builder: (context, ref, _) {
                                        final location =
                                            ref.watch(_locationProvider);
                                        if (location != null) {
                                          return MapPreview(
                                            location: location,
                                            onTap: () async {
                                              Geographic? newValue =
                                                  await showModalBottomSheet(
                                                context: context,
                                                isScrollControlled: true,
                                                enableDrag: false,
                                                isDismissible: false,
                                                builder:
                                                    (BuildContext context) =>
                                                        EventRallyMap(
                                                  initialRallyPoint: ref
                                                      .read(_locationProvider),
                                                  onPlaceSelect: (placeName) {
                                                    if (_locationDescriptionController
                                                        .text.isEmpty) {
                                                      _locationDescriptionController
                                                          .text = placeName;
                                                    }
                                                  },
                                                ),
                                              );

                                              if (newValue != null) {
                                                ref
                                                    .read(_locationProvider
                                                        .notifier)
                                                    .state = newValue;
                                              }
                                            },
                                          );
                                        }
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.map,
                                                size: 32,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Select on Map',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Location Name',
                                  hintText: 'e.g., Central Park, Joe\'s Coffee',
                                  prefixIcon: const Icon(Icons.place),
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withAlpha(80),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter location description';
                                  }
                                  return null;
                                },
                                controller: _locationDescriptionController,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Details Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Additional Details',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Description',
                                  hintText: 'Add any important details...',
                                  alignLabelWithHint: true,
                                  prefixIcon: const Icon(Icons.description),
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withAlpha(80),
                                ),
                                controller: _notesController,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.url],
                                keyboardType: TextInputType.url,
                                decoration: InputDecoration(
                                  labelText: 'Event Link (optional)',
                                  hintText: 'https://',
                                  prefixIcon: const Icon(Icons.link),
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withAlpha(80),
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Visibility Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Who Can See This?',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              FormVisibilityPicker(
                                labelText: '',
                                valueProvider: _visibilityProvider,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: () => _submitEvent(context),
                          child: Text(
                            isNewEvent ? 'Create Event' : 'Save Changes',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
