import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/supabase.dart';
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
}
