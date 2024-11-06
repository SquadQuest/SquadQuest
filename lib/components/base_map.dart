import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:easy_debounce/easy_debounce.dart';

import 'package:squadquest/models/location_point.dart';
import 'package:squadquest/models/map_segment.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/services/profiles_cache.dart';

typedef TrailKey = String;

String makeTrailKey(UserID userId, InstanceID eventId) => '$userId:$eventId';

String generateColorFromUUID(String uuid) {
  // Remove dashes and get first 8 chars for more entropy
  final cleanUuid = uuid.replaceAll('-', '').substring(0, 8);

  // Convert to integer for calculations
  final value = int.parse(cleanUuid, radix: 16);

  // Generate HSL values:
  // Hue: Use full range (0-360) for color variety
  // Saturation: Keep high (70-100%) for vibrant colors
  // Lightness: Keep high (60-80%) for visibility on dark backgrounds
  final hue = value % 360;
  final saturation = 70 + (value % 30); // 70-100%
  final lightness = 60 + (value % 20); // 60-80%

  // Convert HSL to RGB
  final rgb = _hslToRgb(hue / 360, saturation / 100, lightness / 100);

  // Convert RGB to hex
  return '#${rgb.map((c) => c.toRadixString(16).padLeft(2, '0')).join('')}';
}

// Helper function to convert HSL to RGB
List<int> _hslToRgb(double h, double s, double l) {
  double r, g, b;

  if (s == 0) {
    r = g = b = l;
  } else {
    double hue2rgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }

  return [(r * 255).round(), (g * 255).round(), (b * 255).round()];
}

abstract class BaseMap extends ConsumerStatefulWidget {
  const BaseMap({super.key});
}

abstract class BaseMapState<T extends BaseMap> extends ConsumerState<T> {
  static const minSinglePointBounds = 500 / 111000;
  static const minMultiPointBounds = 100 / 111000;

  MapLibreMapController? controller;
  StreamSubscription? subscription;
  List<LocationPoint>? points;
  bool renderingTrails = false;

  final Map<TrailKey, List<Line>> trailsLinesByKey = {};
  final Map<TrailKey, Symbol> symbolsByKey = {};

  @override
  void dispose() {
    controller = null;
    if (subscription != null) {
      subscription!.cancel();
    }
    super.dispose();
  }

  void onMapCreated(MapLibreMapController controller) {
    this.controller = controller;
  }

  Future<void> onStyleLoadedCallback() async {
    if (controller == null) return;

    // configure symbols
    await controller!.setSymbolIconAllowOverlap(true);
    await controller!.setSymbolTextAllowOverlap(true);
    await controller!.addImage(
        'person-marker',
        (await rootBundle.load('assets/symbols/person-marker.png'))
            .buffer
            .asUint8List());

    // Load additional markers if needed
    await loadAdditionalMarkers();

    // load trails
    await loadTrails();
  }

  // Override this to load additional markers (like flag-marker for rally points)
  Future<void> loadAdditionalMarkers() async {}

  // Override this to implement trail loading logic
  Future<void> loadTrails();

  // Override this to provide custom bounds calculation logic
  Map<String, double> getInitialBounds() {
    return {
      'minLatitude': 90,
      'maxLatitude': -90,
      'minLongitude': 180,
      'maxLongitude': -180,
    };
  }

  // Override this to provide custom point filtering
  bool shouldIncludePoint(LocationPoint point) {
    return true;
  }

  Future<void> renderTrails([List<LocationPoint>? points]) async {
    if (points != null) {
      this.points = points;
    }

    EasyDebounce.debounce(
        'render-trails', const Duration(milliseconds: 100), doRenderTrails);
  }

  Future<void> doRenderTrails() async {
    if (renderingTrails || points == null) {
      return;
    }
    renderingTrails = true;

    // group points by user and event
    final Map<TrailKey, List<LocationPoint>> pointsByKey = {};
    final Set<UserID> userIds = {};

    for (final point in points!) {
      if (!shouldIncludePoint(point)) continue;

      final key = makeTrailKey(point.createdBy, point.event);
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

    // get initial bounds
    var bounds = getInitialBounds();
    double minLatitude = bounds['minLatitude']!;
    double maxLatitude = bounds['maxLatitude']!;
    double minLongitude = bounds['minLongitude']!;
    double maxLongitude = bounds['maxLongitude']!;

    final List<TrailKey> keysToRemove = [];
    for (final TrailKey key in pointsByKey.keys) {
      final List<LocationPoint> keyPoints = pointsByKey[key]!;

      // erase and skip if there aren't enough points
      if (keyPoints.length < 2) {
        keysToRemove.add(key);
        continue;
      }

      // build trail segments
      var segments = MapSegment.subdivide(keyPoints, maxDistance: 500 / 111000);

      // render segments to lines with faded color based on distance from lead time
      if (!trailsLinesByKey.containsKey(key)) {
        trailsLinesByKey[key] = [];
      }

      final trailLines = trailsLinesByKey[key]!;

      final earliestMilleseconds = segments.last.earliestMilliseconds;
      final totalMilliseconds = segments.first.latestMilliseconds -
          segments.last.earliestMilliseconds;

      // Generate color based on user UUID
      final userId = keyPoints.first.createdBy;
      final trailColor = generateColorFromUUID(userId);

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
          lineColor: trailColor,
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

    await updateMapBounds(
      minLatitude: minLatitude,
      maxLatitude: maxLatitude,
      minLongitude: minLongitude,
      maxLongitude: maxLongitude,
    );

    renderingTrails = false;
  }

  Future<void> updateMapBounds({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
  }) async {
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
  }

  // Helper method to build map widget
  Widget buildMap() {
    return MapLibreMap(
      onMapCreated: onMapCreated,
      onStyleLoadedCallback: onStyleLoadedCallback,
      initialCameraPosition: const CameraPosition(
        target: LatLng(39.9550, -75.1605),
        zoom: 11.75,
      ),
      styleString:
          'https://api.maptiler.com/maps/08847b31-fc27-462a-b87e-2e8d8a700529/style.json?key=XYHvSt2RxwZPOxjSj98n',
      myLocationEnabled: true,
      myLocationRenderMode: MyLocationRenderMode.compass,
      myLocationTrackingMode: MyLocationTrackingMode.tracking,
    );
  }
}
