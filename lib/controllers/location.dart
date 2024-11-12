import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/router.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/models/instance.dart';

final locationControllerProvider = Provider<LocationController>((ref) {
  return LocationController(ref);
});

final locationStreamProvider = StreamProvider<bg.Location>((ref) {
  final locationController = ref.watch(locationControllerProvider);
  return locationController.stream;
});

final locationSharingProvider = StateProvider<bool?>((ref) {
  return false;
});

class LocationController {
  final Ref ref;

  bool _initialized = false;
  final List<Completer> _onInitialized = [];
  bool _startingTracking = false;
  bool tracking = false;

  final List<InstanceID> _trackingInstanceIds = [];
  bg.Location? _lastLocation;

  final _streamController = StreamController<bg.Location>.broadcast();
  Stream<bg.Location> get stream => _streamController.stream;

  LocationController(this.ref) {
    _init();
  }

  void _init() async {
    // Configure background geolocation
    await bg.BackgroundGeolocation.ready(bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 5, // meters
        stopOnTerminate: false,
        startOnBoot: true,
        debug: false,
        logLevel: bg.Config.LOG_LEVEL_VERBOSE,
        notification: bg.Notification(
          title: "SquadQuest is tracking your location",
          text: "Friends going to the same event can see where you are",
          channelName: 'Location Sharing',
          smallIcon: "ic_stat_person_pin_circle",
        ),
        backgroundPermissionRationale: bg.PermissionRationale(
            title: "Allow SquadQuest to access location in background?",
            message:
                "SquadQuest needs background location access to show your location to friends during events.",
            positiveAction: "Allow",
            negativeAction: "Cancel")));

    // Listen for location updates
    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      _onLocationChanged(location);
    }, (bg.LocationError error) {
      logger.e("BackgroundGeolocation error: $error");
    });

    // listen for changes to events to stop tracking automatically
    ref.listen(
      instancesProvider,
      (oldInstances, instances) async {
        if (instances.value == null) {
          return;
        }

        final now = DateTime.now().toUtc();

        for (final instance in instances.value!) {
          if (!_trackingInstanceIds.contains(instance.id)) {
            continue;
          }

          if (instance.getTimeGroup(now) == InstanceTimeGroup.past) {
            await stopTracking(instance.id);
          }
        }
      },
      fireImmediately: true,
    );

    // mark that initialization is complete
    _initialized = true;

    // complete any queued futures
    if (_onInitialized.isNotEmpty) {
      await startTracking();

      for (final completer in _onInitialized) {
        completer.complete();
      }
    }
  }

  Future<void> startTracking([InstanceID? instanceId]) async {
    // check setting and initialize if needed
    final locationSharingEnabled = ref.read(locationSharingEnabledProvider);

    if (locationSharingEnabled == false) {
      return;
    } else if (locationSharingEnabled == null) {
      final promptResponse = await _showPrompt();
      ref.read(locationSharingEnabledProvider.notifier).state = promptResponse;

      if (promptResponse != true) {
        return;
      }
    }

    // register instanceId
    if (instanceId != null) {
      _trackingInstanceIds.add(instanceId);
    }

    // queue a future to complete after initialization if not initialized yet
    if (!_initialized) {
      final completer = Completer();
      _onInitialized.add(completer);
      return completer.future;
    }

    // if already tracking, return
    if (tracking || _startingTracking) {
      return;
    }
    _startingTracking = true;
    ref.read(locationSharingProvider.notifier).state = null;

    try {
      // Request permissions and check state
      final state = await bg.BackgroundGeolocation.requestPermission();

      if (state != bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS ||
          state != bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE) {
        logger.d('Location tracking not authorized: $state');
        _startingTracking = false;
        ref.read(locationSharingProvider.notifier).state = false;
        return;
      }

      // Start tracking
      await bg.BackgroundGeolocation.start();

      tracking = true;
      ref.read(locationSharingProvider.notifier).state = true;

      logger.d('Location tracking started successfully');
    } catch (error) {
      loggerWithStack.e(error);
      _startingTracking = false;
      ref.read(locationSharingProvider.notifier).state = false;
      return;
    }

    _startingTracking = false;
  }

  Future<void> stopTracking([InstanceID? instanceId]) async {
    // remove instanceId
    if (instanceId == null) {
      _trackingInstanceIds.clear();
    } else {
      _trackingInstanceIds.remove(instanceId);
    }

    // if still tracking other instances, return
    if (_trackingInstanceIds.isNotEmpty) {
      return;
    }

    // stop tracking location
    logger.d('LocationController.stopTracking');

    if (tracking) {
      await bg.BackgroundGeolocation.stop();
      tracking = false;
      ref.read(locationSharingProvider.notifier).state = false;
    }

    logger.d('LocationController.stopTracking -> finished');
  }

  void _onLocationChanged(bg.Location location) async {
    logger.t({'_onLocationChanged': location.toMap()});

    _lastLocation = location;

    // generate records for each active event
    final insertData = _trackingInstanceIds.map((instanceId) {
      return {
        'event': instanceId,
        'timestamp': DateTime.fromMillisecondsSinceEpoch(
                location.timestamp != null
                    ? int.parse(location.timestamp!)
                    : DateTime.now().millisecondsSinceEpoch)
            .toUtc()
            .toIso8601String(),
        'location':
            'POINT(${location.coords.longitude} ${location.coords.latitude})',
      };
    }).toList();

    // write to database
    if (insertData.isNotEmpty) {
      await ref
          .read(supabaseClientProvider)
          .from('location_points')
          .insert(insertData);
    }

    // broadcast on stream
    _streamController.add(location);
  }

  Future<bool?> _showPrompt() {
    return showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location permissions'),
          scrollable: true,
          content: Text('Do you want to share your location?\n\n'
              'Sharing your location will enable other people going to this event'
              ' to see where you are on the map. This can be useful to coordinate'
              ' finding each other and you\'ll be able to stop sharing your location'
              ' at any time.\n\n'
              'For best results, allow the app to "Always" access your location so'
              ' this function works even when the app is in the background.'
              ' ${!kIsWeb && Platform.isIOS ? 'Since you\'re on an Apple device, you will need to go into the app\'s settings manully to enable this.' : ''}\n\n'
              'Your location data will only be shared with other people going to the event'
              ' and be stored on SquadQuest\'s servers for up to 12 hours before being'
              ' permanently deleted.\n\n'
              'A clear banner will be displayed as long as your location is being collected'
              ' and SquadQuest will NEVER collect your location data outside of being on'
              ' your way to an event.\n\n'
              'If you decline, you won\'t be asked again but can go into the app\'s'
              ' settings at any time to change your mind.'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }
}
