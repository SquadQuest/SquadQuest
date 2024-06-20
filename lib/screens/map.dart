import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/drawer.dart';
import 'package:squadquest/services/location.dart';
import 'package:squadquest/services/supabase.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapLibreMapController? controller;

  void _onMapCreated(MapLibreMapController controller) {
    logger.d('MapScreen._onMapCreated');
    this.controller = controller;
  }

  void _onStyleLoadedCallback() async {
    logger.d('MapScreen._onStyleLoadedCallback');
    // await controller!.addLine(
    //   const LineOptions(
    //     geometry: [LatLng(37.4220, -122.0841), LatLng(37.4240, -122.0941)],
    //     lineColor: "#ff0000",
    //     lineWidth: 14.0,
    //     lineOpacity: 0.5,
    //   ),
    // );
    _loadTracks();
  }

  void _loadTracks() async {
    final supabase = ref.read(supabaseClientProvider);
    final points = await supabase
        .from('location_tracks')
        .select('location_text')
        .order('timestamp')
        .withConverter((data) {
      return data.map((row) {
        final [longitude, latitude] = row['location_text']
            .substring(6, row['location_text'].length - 1)
            .split(' ');
        return LatLng(double.parse(latitude), double.parse(longitude));
      }).toList();
    });

    // for (final point in points) {
    //   controller!.addCircle(CircleOptions(
    //     geometry: point,
    //     circleRadius: 5.0,
    //     circleColor: '#ff0000',
    //     circleOpacity: 0.5,
    //   ));
    // }
    controller!.addLine(LineOptions(
      geometry: points,
      lineColor: '#ff0000',
      lineWidth: 5.0,
      lineOpacity: 0.5,
    ));
  }

  @override
  void initState() {
    super.initState();

    final locationService = ref.read(locationServiceProvider);

    locationService.startTracking();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Map'),
        ),
        drawer: const AppDrawer(),
        body: MapLibreMap(
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoadedCallback,
          initialCameraPosition: const CameraPosition(
            target: LatLng(39.9550, -75.1605),
            zoom: 11.75,
          ),
          styleString:
              'https://api.maptiler.com/maps/outdoor-v2/style.json?key=XYHvSt2RxwZPOxjSj98n',
          myLocationEnabled: true,
          myLocationRenderMode: MyLocationRenderMode.compass,
          myLocationTrackingMode: MyLocationTrackingMode.tracking,
        ),
      ),
    );
  }
}
