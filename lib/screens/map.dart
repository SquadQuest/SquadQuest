import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/drawer.dart';
import 'package:squadquest/models/location_point.dart';
import 'package:squadquest/models/map_segment.dart';
import 'package:squadquest/services/supabase.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapLibreMapController? controller;
  StreamSubscription? subscription;
  final List<Line> trackLines = [];
  Line? traceLine;
  Circle? traceCircle;

  void _onMapCreated(MapLibreMapController controller) {
    logger.d('MapScreen._onMapCreated');
    this.controller = controller;
  }

  void _onStyleLoadedCallback() async {
    logger.d('MapScreen._onStyleLoadedCallback');
    await controller!.addImage(
        'person-marker',
        (await rootBundle.load('assets/symbols/person-marker.png'))
            .buffer
            .asUint8List());

    await controller!.addSymbol(const SymbolOptions(
        geometry: LatLng(39.9550, -75.1605),
        iconImage: 'person-marker',
        iconSize: kIsWeb ? 0.25 : 0.75,
        iconAnchor: 'bottom',
        textField: 'Full Name',
        textColor: '#ffffff',
        textAnchor: 'top-left',
        textSize: 8));

    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final supabase = ref.read(supabaseClientProvider);

    subscription = supabase
        .from('location_points')
        .stream(primaryKey: ['id'])
        .eq('created_by', supabase.auth.currentUser!.id)
        .order('timestamp', ascending: false)
        .listen((data) {
          final List<LocationPoint> points =
              data.map(LocationPoint.fromMap).toList();

          _renderTracks(points);
        });
  }

  Future<void> _renderTracks(List<LocationPoint> points) async {
    logger.d({'rendering tracks': points.length});
    // clear existing line and skip if points list is empty
    if (points.length < 2) {
      if (trackLines.isNotEmpty) {
        for (var line in trackLines) {
          await controller!.removeLine(line);
        }
        trackLines.clear();
      }

      if (traceLine != null) {
        await controller!.removeLine(traceLine!);
        traceLine = null;
      }

      if (traceCircle != null) {
        await controller!.removeCircle(traceCircle!);
        traceCircle = null;
      }

      return;
    }

    // render trace line
    // final traceLineOptions = LineOptions(
    //     geometry: points
    //         .map((point) => LatLng(point.position.lat, point.position.lon))
    //         .toList(),
    //     lineColor: '#00ff00',
    //     lineWidth: 2.0,
    //     lineOpacity: 1);

    // if (traceLine == null) {
    //   traceLine = await controller!.addLine(traceLineOptions);
    // } else {
    //   await controller!.updateLine(traceLine!, traceLineOptions);
    // }

    // render trace circle
    // final traceCircleOptions = CircleOptions(
    //   geometry: LatLng(points.first.position.lat, points.first.position.lon),
    //   circleColor: '#00ff00',
    //   circleRadius: 5.0,
    //   circleOpacity: 0.25,
    // );

    // if (traceCircle == null) {
    //   traceCircle = await controller!.addCircle(traceCircleOptions);
    // } else {
    //   await controller!.updateCircle(traceCircle!, traceCircleOptions);
    // }

    // build segments
    var segments =
        MapSegment.subdivide(points, threshold: .0001, maxDistance: .005);

    // render segments to lines with faded color based on distance from lead time
    final earliestMilleseconds = segments.last.earliestMilliseconds;
    final totalMilliseconds =
        segments.first.latestMilliseconds - segments.last.earliestMilliseconds;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];

      final lineOptions = LineOptions(
        geometry: segment.latLngList,
        lineColor: '#ff0000',
        lineWidth: 5.0,
        lineOpacity: (segment.midMilliseconds - earliestMilleseconds) /
            totalMilliseconds, // TODO: calculate based on average time
      );

      if (trackLines.length <= i) {
        trackLines.add(await controller!.addLine(lineOptions));
      } else {
        await controller!.updateLine(trackLines[i], lineOptions);
      }
    }

    // remove unused lines
    if (trackLines.length > segments.length) {
      for (var i = segments.length; i < trackLines.length; i++) {
        await controller!.removeLine(trackLines[i]);
      }

      trackLines.removeRange(segments.length, trackLines.length);
    }

    logger.d({
      // 'lineString.chain.positions.length': lineString.chain.positions.length,
      // 'samplePoints.length': samplePoints.length,
      // 'lineString.length2D()': lineString.length2D(),
      'segments.length': segments.length,
      'segments map sum': segments
          .map((segment) => segment.distance)
          .reduce((value, element) => value + element),
      'segments length count': segments
          .map((segment) => segment.length)
          .reduce((value, element) => value + element),
    });
  }

  @override
  void initState() {
    super.initState();
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
              'https://api.maptiler.com/maps/08847b31-fc27-462a-b87e-2e8d8a700529/style.json?key=XYHvSt2RxwZPOxjSj98n',
          myLocationEnabled: true,
          myLocationRenderMode: MyLocationRenderMode.compass,
          myLocationTrackingMode: MyLocationTrackingMode.tracking,
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller = null;

    if (subscription != null) {
      subscription!.cancel();
    }

    super.dispose();
  }
}
