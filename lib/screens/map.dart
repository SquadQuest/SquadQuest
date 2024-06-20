import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/drawer.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final Location _location = new Location();
  bool _serviceEnabled = false;
  PermissionStatus? _permissionGranted;
  LocationData? _locationData;

  @override
  void initState() {
    super.initState();

    _initializeLocation();
  }

  void _initializeLocation() async {
    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationData = await _location.getLocation();

    _location.onLocationChanged.listen((LocationData currentLocation) {
      logger.d({'location': currentLocation});
    });
  }

  @override
  Widget build(BuildContext context) {
    // _updateUserLocation(ref);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Map'),
        ),
        drawer: const AppDrawer(),
        body: MapLibreMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(39.9550, -75.1605),
            zoom: 11.75,
          ),
          styleString:
              'https://api.maptiler.com/maps/outdoor-v2/style.json?key=XYHvSt2RxwZPOxjSj98n',
          myLocationEnabled: true,
          myLocationRenderMode: MyLocationRenderMode.compass,
          myLocationTrackingMode: MyLocationTrackingMode.tracking,
          // markers: userLocation != null
          //     ? [
          //         Marker(
          //           id: 'user-location',
          //           position: userLocation,
          //         ),
          //       ]
          //     : [],
        ),
      ),
    );
  }
}
