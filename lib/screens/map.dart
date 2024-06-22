import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/drawer.dart';
import 'package:squadquest/services/location.dart';
import 'package:squadquest/services/supabase.dart';

typedef PointRecord = ({DateTime timestamp, Geographic position});

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
    _loadTracks();
  }

  void _loadTracks() async {
    final supabase = ref.read(supabaseClientProvider);

    // final positionTimestamps = <Geographic, DateTime>{};
    final List<PointRecord> points = await supabase
        .from('location_tracks')
        .select('timestamp, location_text')
        .eq('created_by', supabase.auth.currentUser!.id)
        .order('timestamp', ascending: false)
        // TODO: limit to last ~hour or less
        .withConverter((data) {
      return data.map((row) {
        final [longitude, latitude] = row['location_text']
            .substring(6, row['location_text'].length - 1)
            .split(' ');
        return (
          timestamp: DateTime.parse(row['timestamp']),
          position: Geographic(
              lon: double.parse(longitude), lat: double.parse(latitude))
        );
      }).toList();
    });

    // reduce test list to 100 points
    final pointsSubset = points.sublist(1600, 1700);
    final samplePoints = [
      for (var i = 0; i < pointsSubset.length; i += 5) pointsSubset[i]
    ];

    final lineString =
        LineString.from(samplePoints.map((point) => point.position));

    var segments = _Segment.subdivide(samplePoints, threshold: .002);

    // render segments to lines with faded color based on distance from lead time
    // for (var i = 0; i < segments.length; i++) {
    //   final segment = segments[i];
    //   final segmentDistance = segment.length2D();

    //   await controller!.addLine(LineOptions(
    //     geometry: segment.chain.positions
    //         .map((position) => LatLng(position.y, position.x))
    //         .toList(),
    //     lineColor: '#ff0000',
    //     lineWidth: 5.0,
    //     lineOpacity:
    //         i / segments.length, // TODO: calculate based on average time
    //   ));
    // }

    logger.d({
      'lineString.chain.positions.length': lineString.chain.positions.length,
      'samplePoints.length': samplePoints.length,
      'lineString.length2D()': lineString.length2D(),
      'segments.length': segments.length,
    });

    logger.d('done');

    // TODO: create method that takes a the points list and a cursor index and returns a list of
    // lines up to a threshold distance where each line subdivides the list of points by a fixed
    // portion of the total time of the segment. Color the lines based on their average distance from the lead time
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

class _Segment {
  final List<PointRecord> pointRecords;

  LineString? _lineString;
  LineString get lineString =>
      _lineString ??
      (_lineString = LineString.from(
          pointRecords.map((record) => record.position).toList()));

  double? _distance;
  double get distance => _distance ?? (_distance = lineString.length2D());

  int get length => pointRecords.length;

  _Segment(this.pointRecords);

  static subdivide(List<PointRecord> points, {double threshold = 0.002}) {
    final segments = <_Segment>[];

    int currentSegmentStart = 0;
    _Segment? currentSegment;

    double distanceSum = 0;

    for (int i = currentSegmentStart + 1; i < points.length; i++) {
      currentSegment = _Segment(points.sublist(currentSegmentStart, i + 1));

      logger.d({
        "currentSegment($currentSegmentStart -> ${i + 1}).length2D()":
            currentSegment.distance,
        "currentSegment.length": currentSegment.length,
      });

      if (currentSegment.distance > threshold) {
        logger.d('pushing segment');
        segments.add(currentSegment);
        distanceSum += currentSegment.distance;

        currentSegment = null;
        currentSegmentStart = i;
        continue;
      }
    }

    // add final segment
    if (currentSegment != null) {
      logger.d('pushing last segment');
      segments.add(currentSegment);
      distanceSum += currentSegment.distance;
    }

    logger.d({
      'segments.length': segments.length,
      'distanceSum': distanceSum,
      'segments map sum': segments
          .map((segment) => segment.distance)
          .reduce((value, element) => value + element),
      'segments length count': segments
          .map((segment) => segment.length)
          .reduce((value, element) => value + element),
    });

    return segments;
  }
}
