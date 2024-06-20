import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/supabase.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(ref);
});

final locationStreamProvider = StreamProvider<LocationData>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.stream;
});

class LocationService {
  final Ref ref;

  late Location _location;
  bool _serviceEnabled = false;
  bool _backgroundEnabled = false;
  PermissionStatus? _permissionGranted;
  LocationData? _lastLocation;

  final _streamController = StreamController<LocationData>.broadcast();
  Stream<LocationData> get stream => _streamController.stream;

  LocationService(this.ref) {
    _init();
  }

  void _init() async {
    _location = Location();
    _location.changeSettings(
        interval: 5000,
        distanceFilter:
            5); // sample location every 5 seconds if distance is at least 5 meters
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
      'LocationService._init': {
        'serviceEnabled': _serviceEnabled,
        'permissionGranted': _permissionGranted,
      }
    });
  }

  void startTracking() async {
    logger.d('LocationService.startTracking');

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

    _backgroundEnabled = await _location.enableBackgroundMode(enable: true);

    _lastLocation = await _location.getLocation();

    if (_lastLocation != null) {
      _streamController.add(_lastLocation!);
    }

    _location.onLocationChanged.listen(_onLocationChanged);

    logger.d({
      'serviceEnabled': _serviceEnabled,
      'permissionGranted': _permissionGranted,
      'backgroundEnabled': _backgroundEnabled,
      'lastLocation': _lastLocation
    });
  }

  void _onLocationChanged(LocationData currentLocation) async {
    logger.t({'_onLocationChanged': currentLocation});

    _lastLocation = currentLocation;

    // write to database
    final supabase = ref.read(supabaseClientProvider);

    // TODO: save more of the available data?
    await supabase.from('location_points').insert({
      'timestamp':
          DateTime.fromMillisecondsSinceEpoch(currentLocation.time!.toInt())
              .toUtc()
              .toIso8601String(),
      'location':
          'POINT(${currentLocation.longitude} ${currentLocation.latitude})',
    });

    // broadcast on stream
    _streamController.add(currentLocation);
  }
}
