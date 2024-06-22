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
  final List<Line> trackLines = [];
  Line? traceLine;
  Circle? traceCircle;

  void _onMapCreated(MapLibreMapController controller) {
    logger.d('MapScreen._onMapCreated');
    this.controller = controller;
  }

  void _onStyleLoadedCallback() async {
    logger.d('MapScreen._onStyleLoadedCallback');
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final supabase = ref.read(supabaseClientProvider);

    // final positionTimestamps = <Geographic, DateTime>{};
    // TODO: select from raw points
    supabase
        .from('location_points')
        .stream(primaryKey: ['id'])
        .eq('created_by', supabase.auth.currentUser!.id)
        .order('timestamp', ascending: false)
        .listen((data) {
          final List<PointRecord> points = data.map((row) {
            final [longitude, latitude] = row['location_text']
                .substring(6, row['location_text'].length - 1)
                .split(' ');
            return (
              timestamp: DateTime.parse(row['timestamp']),
              position: Geographic(
                  lon: double.parse(longitude), lat: double.parse(latitude))
            );
          }).toList();

          _renderTracks(points);
        });
  }

  Future<void> _renderTracks(List<PointRecord> points) async {
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
        _Segment.subdivide(points, threshold: .0001, maxDistance: .005);

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

  // basic information
  int get length => pointRecords.length;
  DateTime get earliest => pointRecords.last.timestamp;
  int get earliestMilliseconds => earliest.millisecondsSinceEpoch;
  DateTime get latest => pointRecords.first.timestamp;
  int get latestMilliseconds => latest.millisecondsSinceEpoch;

  // geobase representations
  LineString? _lineString;
  LineString get lineString =>
      _lineString ??
      (_lineString = LineString.from(
          pointRecords.map((record) => record.position).toList()));
  Iterable<Position> get positions => lineString.chain.positions;

  // maplibre representations
  List<LatLng> get latLngList =>
      positions.map((position) => LatLng(position.y, position.x)).toList();

  // calculations
  double? _distance;
  double get distance => _distance ?? (_distance = lineString.length2D());

  int? _durationMilliseconds;
  int get durationMilliseconds => latestMilliseconds - earliestMilliseconds;
  Duration? _duration;
  Duration get duration =>
      _duration ?? (_duration = Duration(milliseconds: durationMilliseconds));

  int? _midMilliseconds;
  int get midMilliseconds =>
      _midMilliseconds ?? (earliestMilliseconds + durationMilliseconds ~/ 2);
  DateTime? _midTimestamp;
  DateTime get midTimestamp =>
      _midTimestamp ??
      (_midTimestamp = DateTime.fromMillisecondsSinceEpoch(midMilliseconds));

  _Segment(this.pointRecords)
      : assert(pointRecords.length >= 2,
            'pointRecords must have at least 2 entries'),
        assert(
            pointRecords.first.timestamp.isAfter(pointRecords.last.timestamp),
            'pointRecords must be in reverse chronological order');

  static subdivide(List<PointRecord> points,
      {double threshold = 0.002, double? maxDistance}) {
    final segments = <_Segment>[];

    int currentSegmentStart = 0;
    _Segment? currentSegment;
    double distanceSum = 0;

    for (int i = currentSegmentStart + 1; i < points.length; i++) {
      // skip point if it is a duplicate of the last point
      if (i > 0 &&
          points[i].timestamp.isAtSameMomentAs(points[i - 1].timestamp)) {
        continue;
      }

      // draft current segment
      currentSegment = _Segment(points.sublist(currentSegmentStart, i + 1));

      // complete segment if distance exceeds threshold
      if (currentSegment.distance > threshold) {
        segments.add(currentSegment);
        distanceSum += currentSegment.distance;

        currentSegment = null;
        currentSegmentStart = i;

        if (maxDistance != null && distanceSum > maxDistance) {
          break;
        } else {
          continue;
        }
      }
    }

    // add final segment
    if (currentSegment != null) {
      segments.add(currentSegment);
      distanceSum += currentSegment.distance;
    }

    return segments;
  }
}
