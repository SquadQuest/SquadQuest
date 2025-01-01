import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/coordinates.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/logger.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/services/router.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/instances.dart';

import 'widgets/event_form_banner.dart';
import 'widgets/event_form_who.dart';
import 'widgets/event_form_what.dart';
import 'widgets/event_form_when.dart';
import 'widgets/event_form_where.dart';
import 'widgets/event_form_submit.dart';

class EventEditScreen extends ConsumerStatefulWidget {
  final InstanceID? instanceId;
  final InstanceID? duplicateEventId;

  const EventEditScreen({super.key, this.instanceId, this.duplicateEventId})
      : assert(instanceId == null || duplicateEventId == null,
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
  final _trailProvider = StateProvider<List<Geographic>?>((ref) => null);
  final _startTimeMinProvider = StateProvider<TimeOfDay?>(
      (ref) => addMinutesToTimeOfDay(TimeOfDay.now(), 60));
  final _startTimeMaxProvider = StateProvider<TimeOfDay?>(
      (ref) => addMinutesToTimeOfDay(TimeOfDay.now(), 75));
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
    final List<Geographic>? trail = ref.read(_trailProvider);

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

    if (endDateTime != null && endDateTime.isBefore(startDateTimeMax)) {
      return _showValidationError(
          'Please select an end time after latest start time or none at all');
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

    if (bannerPhoto != null && !isUploadedPhoto(bannerPhoto, supabase)) {
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

      // For private events with no topic, use the default misc.hangout topic
      Topic? topic = ref.read(_topicProvider);

      if (visibility == InstanceVisibility.private &&
          (topic == null || topic.isNull)) {
        topic = defaultPrivateTopic;
      }

      final Instance draftInstance = Instance(
          id: _editingInstance.value?.id,
          createdAt: _editingInstance.value?.createdAt,
          createdBy: _editingInstance.value?.createdBy,
          title: _titleController.text.trim(),
          topic: topic,
          startTimeMin: startDateTimeMin,
          startTimeMax: startDateTimeMax,
          visibility: visibility,
          locationDescription: _locationDescriptionController.text.trim(),
          rallyPoint: rallyPoint,
          trail: trail,
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
            upsert: true, transform: const TransformOptions(width: 1024));
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
    ref.read(_trailProvider.notifier).state = instance.trail;
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
      loadMask = 'Duplicating event...';
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

    // default: create a new event from scratch
    isNewEvent = true;
    _editingInstance = const AsyncValue.data(null);
  }

  Future<void> _importEvent() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = clipboardData?.text;

    if (clipboardText == null || clipboardText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL found in clipboard')),
      );
      return;
    }

    // Basic URL validation
    Uri? url;
    try {
      url = Uri.parse(clipboardText);
      if (!url.hasScheme || !url.hasAuthority) {
        throw FormatException('Invalid URL');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard content is not a valid URL')),
      );
      return;
    }

    setState(() {
      loadMask = 'Importing event...';
      _editingInstance = const AsyncValue.loading();
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'scrape-event',
        method: HttpMethod.get,
        queryParameters: {'url': clipboardText},
      );

      final instance = Instance.fromMap(response.data);

      setState(() {
        _loadValuesFromInstance(instance);
        _editingInstance = const AsyncValue.data(null);
        loadMask = null;
      });
    } catch (error) {
      logger.e('Error importing event', error: error);

      setState(() {
        _editingInstance = const AsyncValue.data(null);
        loadMask = null;
      });

      if (!mounted) return;

      final message = error is FunctionException
          ? (error.details is String
              ? error.details.replaceAll(RegExp(r'^[a-z\-]+: '), '')
              : error.details?['message'])
          : error;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import event: ${message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
                'Are you sure you want to leave? Any changes will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );

        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AppScaffold(
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
        showLocationSharingSheet: false,
        actions: isNewEvent
            ? [
                IconButton(
                  icon: const Icon(Icons.content_paste),
                  tooltip: 'Import Event from Clipboard',
                  onPressed: _importEvent,
                ),
              ]
            : null,
        body: _editingInstance.when(
          error: (error, __) => Center(child: Text(error.toString())),
          loading: () => const SizedBox.shrink(),
          data: (Instance? instance) => Form(
            key: _formKey,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: EventFormBanner(
                    bannerPhotoProvider: _bannerPhotoProvider,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EventFormWho(
                          visibilityProvider: _visibilityProvider,
                        ),
                        const SizedBox(height: 16),
                        EventFormWhat(
                          titleController: _titleController,
                          topicProvider: _topicProvider,
                          linkController: _linkController,
                          notesController: _notesController,
                          visibilityProvider: _visibilityProvider,
                        ),
                        const SizedBox(height: 16),
                        EventFormWhen(
                          startDate: startDate,
                          onDateSelected: (date) {
                            setState(() {
                              startDate = date;
                            });
                          },
                          startTimeMinProvider: _startTimeMinProvider,
                          startTimeMaxProvider: _startTimeMaxProvider,
                          endTimeProvider: _endTimeProvider,
                          isNewEvent: isNewEvent,
                          instance: instance,
                        ),
                        const SizedBox(height: 16),
                        EventFormWhere(
                          locationProvider: _locationProvider,
                          trailProvider: _trailProvider,
                          locationDescriptionController:
                              _locationDescriptionController,
                        ),
                        const SizedBox(height: 32),
                        EventFormSubmit(
                          onSubmit: () => _submitEvent(context),
                          isNewEvent: isNewEvent,
                          isSubmitting: submitted ||
                              _editingInstance.isLoading ||
                              loadMask != null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
