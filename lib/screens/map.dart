import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:easy_debounce/easy_debounce.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/drawer.dart';
import 'package:squadquest/models/location_point.dart';
import 'package:squadquest/models/map_segment.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/profiles_cache.dart';

typedef TrailKey = String;

TrailKey _makeTrailKey(UserID userId, InstanceID eventId) => '$userId:$eventId';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const minSinglePointBounds = .005;
  static const minMultiPointBounds = .001;

  MapLibreMapController? controller;
  StreamSubscription? subscription;
  final Map<TrailKey, List<Line>> trailsLinesByKey = {};
  final Map<TrailKey, Symbol> symbolsByKey = {};
  List<LocationPoint>? points;
  bool renderingTrails = false;

  void _onMapCreated(MapLibreMapController controller) {
    logger.d('MapScreen._onMapCreated');
    this.controller = controller;
  }

  void _onStyleLoadedCallback() async {
    logger.d('MapScreen._onStyleLoadedCallback');

    // configure symbols
    await controller!.setSymbolIconAllowOverlap(true);
    await controller!.setSymbolTextAllowOverlap(true);
    await controller!.addImage(
        'person-marker',
        (await rootBundle.load('assets/symbols/person-marker.png'))
            .buffer
            .asUint8List());

    // load trails
    await _loadTrails();
  }

  Future<void> _loadTrails() async {
    final supabase = ref.read(supabaseClientProvider);

    subscription = supabase
        .from('location_points')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .listen((data) {
          final List<LocationPoint> points =
              data.map(LocationPoint.fromMap).toList();

          _renderTrails(points);
        });
  }

  Future<void> _renderTrails([List<LocationPoint>? points]) async {
    if (points != null) {
      this.points = points;
    }

    EasyDebounce.debounce(
        'render-trails', const Duration(milliseconds: 100), _doRenderTrails);
  }

  Future<void> _doRenderTrails() async {
    // prevent parallel executions and skip if no points available
    if (renderingTrails || points == null) {
      return;
    }
    renderingTrails = true;

    // group points by user and event
    final Map<TrailKey, List<LocationPoint>> pointsByKey = {};
    final Set<UserID> userIds = {};

    for (final point in points!) {
      final key = _makeTrailKey(point.createdBy, point.event);
      if (!pointsByKey.containsKey(key)) {
        pointsByKey[key] = [];
      }
      pointsByKey[key]!.add(point);
      userIds.add(point.createdBy);
    }

    // load user profiles
    final userProfiles =
        await ref.read(profilesCacheProvider.notifier).fetchProfiles(userIds);

    // abort if controller disposed
    if (controller == null) return;

    // render each user's symbol and trail for each event
    double minLatitude = 90;
    double maxLatitude = -90;
    double minLongitude = 180;
    double maxLongitude = -180;

    final List<TrailKey> keysToRemove = [];
    for (final TrailKey key in pointsByKey.keys) {
      final List<LocationPoint> keyPoints = pointsByKey[key]!;

      // erase and skip if there aren't enough points
      if (keyPoints.length < 2) {
        keysToRemove.add(key);
        continue;
      }

      // build trail segments
      var segments =
          MapSegment.subdivide(keyPoints, threshold: .0001, maxDistance: .005);

      // render segments to lines with faded color based on distance from lead time
      if (!trailsLinesByKey.containsKey(key)) {
        trailsLinesByKey[key] = [];
      }

      final trailLines = trailsLinesByKey[key]!;

      final earliestMilleseconds = segments.last.earliestMilliseconds;
      final totalMilliseconds = segments.first.latestMilliseconds -
          segments.last.earliestMilliseconds;
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];

        // find min/max lat/lon
        for (final point in segment.points) {
          if (point.location.lat < minLatitude) {
            minLatitude = point.location.lat;
          }
          if (point.location.lat > maxLatitude) {
            maxLatitude = point.location.lat;
          }
          if (point.location.lon < minLongitude) {
            minLongitude = point.location.lon;
          }
          if (point.location.lon > maxLongitude) {
            maxLongitude = point.location.lon;
          }
        }

        // build line
        final lineOptions = LineOptions(
          geometry: segment.latLngList,
          lineColor: '#ff0000',
          lineWidth: 5.0,
          lineOpacity: (segment.midMilliseconds - earliestMilleseconds) /
              totalMilliseconds,
        );

        // render line for segment
        if (trailLines.length <= i) {
          trailLines.add(await controller!.addLine(lineOptions));
        } else {
          await controller!.updateLine(trailLines[i], lineOptions);
        }
      }

      // remove any unused segment lines
      if (trailLines.length > segments.length) {
        for (var i = segments.length; i < trailLines.length; i++) {
          await controller!.removeLine(trailLines[i]);
        }

        trailLines.removeRange(segments.length, trailLines.length);
      }

      // render user marker at latest position
      final userId = keyPoints.first.createdBy;
      final symbolOptions = SymbolOptions(
          geometry: LatLng(
              keyPoints.first.location.lat, keyPoints.first.location.lon),
          iconImage: 'person-marker',
          iconSize: kIsWeb ? 0.4 : 0.9,
          iconAnchor: 'bottom',
          textField: userProfiles[userId]!.displayName,
          textColor: '#ffffff',
          textAnchor: 'top-left',
          textSize: 14);

      if (symbolsByKey.containsKey(key)) {
        await controller!.updateSymbol(symbolsByKey[key]!, symbolOptions);
      } else {
        symbolsByKey[key] =
            await controller!.addSymbol(symbolOptions, {'user': userId});
      }
    }

    // remove any trails with too few points
    for (final key in keysToRemove) {
      pointsByKey.remove(key);
    }

    // remove any unused symbols
    for (final key in symbolsByKey.keys.toList()) {
      if (!pointsByKey.containsKey(key)) {
        await controller!.removeSymbol(symbolsByKey[key]!);
        symbolsByKey.remove(key);
      }
    }

    for (final key in trailsLinesByKey.keys.toList()) {
      if (!pointsByKey.containsKey(key)) {
        for (final line in trailsLinesByKey[key]!) {
          await controller!.removeLine(line);
        }
        trailsLinesByKey.remove(key);
      }
    }

    // apply minimum bounds
    if ((minLatitude - maxLatitude).abs() <= minSinglePointBounds &&
        (minLongitude - maxLongitude).abs() <= minSinglePointBounds) {
      // zoom out more from single-point bounds
      minLatitude -= minSinglePointBounds;
      maxLatitude += minSinglePointBounds;
      minLongitude -= minSinglePointBounds;
      maxLongitude += minSinglePointBounds;
    } else {
      final diffLatitude = (maxLatitude - minLatitude).abs();
      final diffLongitude = (maxLongitude - minLongitude).abs();

      if (diffLatitude < minMultiPointBounds &&
          diffLongitude < minMultiPointBounds) {
        // zoom out more from small bounds
        minLatitude -= minMultiPointBounds - diffLatitude;
        maxLatitude += minMultiPointBounds - diffLatitude;
        minLongitude -= minMultiPointBounds - diffLongitude;
        maxLongitude += minMultiPointBounds - diffLongitude;
      }
    }

    // move camera to new bounds unless they're still the defaults
    if (minLatitude != 90 && minLongitude != 180) {
      await controller!.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(
              northeast: LatLng(maxLatitude, maxLongitude),
              southwest: LatLng(minLatitude, minLongitude)),
          left: 50,
          right: 50,
          top: 50,
          bottom: 50));
    }

    renderingTrails = false;
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
