import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/router.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/models/instance.dart';

final locationControllerProvider = Provider<LocationController>((ref) {
  return LocationController(ref);
});

final locationStreamProvider = StreamProvider<LocationData>((ref) {
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

  StreamSubscription? _streamSubscription;
  final List<InstanceID> _trackingInstanceIds = [];

  late Location _location;
  bool _serviceEnabled = false;
  bool _backgroundEnabled = false;
  PermissionStatus? _permissionGranted;
  LocationData? _lastLocation;

  final _streamController = StreamController<LocationData>.broadcast();
  Stream<LocationData> get stream => _streamController.stream;

  LocationController(this.ref) {
    _init();
  }

  void _init() async {
    _location = Location();
    _location.changeNotificationOptions(
        channelName: 'Location Sharing',
        onTapBringToFront: true,
        iconName: 'ic_stat_person_pin_circle',
        title: 'SquadQuest is tracking your location',
        subtitle: 'Friends going to the same event can see where you are',
        description: 'Tracks stored for 3 days');

    _serviceEnabled = await _location.serviceEnabled();
    _permissionGranted = await _location.hasPermission();

    logger.d({
      'LocationController._init': {
        'serviceEnabled': _serviceEnabled,
        'permissionGranted': _permissionGranted,
      }
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
      // start tracking location
      logger.d('LocationController.startTracking');
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) {
          return;
        }
      }

      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          return;
        }
      }

      // this call can only be made after permission is granted
      _location.changeSettings(
          interval: 5000,
          distanceFilter:
              5); // sample location every 5 seconds if distance is at least 5 meters

      _backgroundEnabled = await _location.enableBackgroundMode(enable: true);
    } catch (error) {
      loggerWithStack.e(error);
    }

    _streamSubscription =
        _location.onLocationChanged.listen(_onLocationChanged);

    logger.d({
      'serviceEnabled': _serviceEnabled,
      'permissionGranted': _permissionGranted,
      'backgroundEnabled': _backgroundEnabled,
      'lastLocation': _lastLocation
    });

    _startingTracking = false;
    tracking =
        _serviceEnabled && _permissionGranted == PermissionStatus.granted;
    ref.read(locationSharingProvider.notifier).state = tracking;

    // force an initial location fetch but don't wait for it
    _location.getLocation().then((initialLocation) {
      logger.d(
          'LocationController.startTracking -> initial location fetched: $initialLocation');
    });

    logger.d('LocationController.startTracking -> finished');
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
      await _streamSubscription?.cancel();
      try {
        await _location.enableBackgroundMode(enable: false);
      } catch (error) {
        loggerWithStack.e(error);
      }
      tracking = false;
      ref.read(locationSharingProvider.notifier).state = false;
    }

    logger.d('LocationController.stopTracking -> finished');
  }

  void _onLocationChanged(LocationData currentLocation) async {
    logger.t({'_onLocationChanged': currentLocation});

    _lastLocation = currentLocation;

    // generate records for each active event
    final insertData = _trackingInstanceIds.map((instanceId) {
      // TODO: save more of the available data?
      return {
        'event': instanceId,
        'timestamp':
            DateTime.fromMillisecondsSinceEpoch(currentLocation.time!.toInt())
                .toUtc()
                .toIso8601String(),
        'location':
            'POINT(${currentLocation.longitude} ${currentLocation.latitude})',
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
    _streamController.add(currentLocation);
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
