import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/location_point.dart';
import 'package:squadquest/models/map_segment.dart';
import 'package:squadquest/models/user.dart';

class EventLiveMap extends ConsumerStatefulWidget {
  final String title;
  final InstanceID eventId;
  final LatLng? rallyPoint;

  const EventLiveMap(
      {super.key,
      this.title = 'Live map',
      required this.eventId,
      this.rallyPoint});

  @override
  ConsumerState<EventLiveMap> createState() => _EventLiveMapState();
}

class _EventLiveMapState extends ConsumerState<EventLiveMap> {
  MapLibreMapController? controller;
  final Map<UserID, List<Line>> trailsLinesByUser = {};
  final Map<UserID, Symbol> symbolsByUser = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SizedBox(
        height: MediaQuery.of(context).size.height * .75,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
              child: MapLibreMap(
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoadedCallback,
            styleString:
                'https://api.maptiler.com/maps/08847b31-fc27-462a-b87e-2e8d8a700529/style.json?key=XYHvSt2RxwZPOxjSj98n',
            myLocationEnabled: true,
            myLocationRenderMode: MyLocationRenderMode.compass,
            myLocationTrackingMode: MyLocationTrackingMode.tracking,
            initialCameraPosition: const CameraPosition(
              target: LatLng(39.9550, -75.1605),
              zoom: 11.75,
            ),
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          ))
        ]));
  }

  void _onMapCreated(MapLibreMapController controller) {
    logger.d('EventLiveMap._onMapCreated');
    this.controller = controller;
  }

  void _onStyleLoadedCallback() async {
    logger.d('EventLiveMap._onStyleLoadedCallback');

    // configure symbols
    await controller!.setSymbolIconAllowOverlap(true);
    await controller!.setSymbolTextAllowOverlap(true);
    await controller!.addImage(
        'person-marker',
        (await rootBundle.load('assets/symbols/person-marker.png'))
            .buffer
            .asUint8List());
    await controller!.addImage(
        'flag-marker',
        (await rootBundle.load('assets/symbols/flag-marker.png'))
            .buffer
            .asUint8List());

    // add rally point
    if (widget.rallyPoint != null) {
      await controller!.addSymbol(SymbolOptions(
          geometry: widget.rallyPoint,
          iconImage: 'flag-marker',
          iconSize: kIsWeb ? 0.05 : 0.2, // TODO: test web scale
          iconAnchor: 'bottom-left'));
    }

    // load trails
    await _loadTrails();
  }

  Future<void> _loadTrails() async {
    final supabase = ref.read(supabaseClientProvider);

    supabase
        .from('location_points')
        .stream(primaryKey: ['id'])
        .eq('event', widget.eventId)
        .order('timestamp', ascending: false)
        .listen((data) {
          final List<LocationPoint> points =
              data.map(LocationPoint.fromMap).toList();

          _renderTrails(points);
        });
  }

  Future<void> _renderTrails(List<LocationPoint> points) async {
    logger.d({'rendering trails': points.length});

    // group points by user
    final Map<UserID, List<LocationPoint>> pointsByUser = {};
    for (final point in points) {
      if (!pointsByUser.containsKey(point.createdBy)) {
        pointsByUser[point.createdBy] = [];
      }

      pointsByUser[point.createdBy]!.add(point);
    }

    logger.d({
      'pointsByUser': pointsByUser
          .map((userId, userPoints) => MapEntry(userId, userPoints.length))
    });

    // load user profiles
    final userProfiles = await ref
        .read(profilesCacheProvider.notifier)
        .fetchProfiles(pointsByUser.keys.toSet());

    // render each user's symbol and trail
    double minLatitude = 90;
    double maxLatitude = -90;
    double minLongitude = 180;
    double maxLongitude = -180;

    for (final UserID userId in pointsByUser.keys) {
      final List<LocationPoint> userPoints = pointsByUser[userId]!;

      // erase and skip user if there aren't enough points—cleanup code later will then delete any existing lines/symbols
      if (userPoints.length < 2) {
        pointsByUser.remove(userId);
        continue;
      }

      // build trail segments
      var segments =
          MapSegment.subdivide(userPoints, threshold: .0001, maxDistance: .005);

      // render segments to lines with faded color based on distance from lead time
      if (!trailsLinesByUser.containsKey(userId)) {
        trailsLinesByUser[userId] = [];
      }

      final trailLines = trailsLinesByUser[userId]!;

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
              totalMilliseconds, // TODO: calculate based on average time
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

      // render user marker at latest poisition
      final symbolOptions = SymbolOptions(
          geometry: LatLng(
              userPoints.first.location.lat, userPoints.first.location.lon),
          iconImage: 'person-marker',
          iconSize: kIsWeb ? 0.25 : 0.75,
          iconAnchor: 'bottom',
          textField: userProfiles[userId]!.fullName,
          textColor: '#ffffff',
          textAnchor: 'top-left',
          textSize: 8);

      if (symbolsByUser.containsKey(userId)) {
        await controller!.updateSymbol(symbolsByUser[userId]!, symbolOptions);
      } else {
        symbolsByUser[userId] =
            await controller!.addSymbol(symbolOptions, {'user': userId});
      }
    }

    // remove any unused symbols
    for (final userId in symbolsByUser.keys) {
      if (!pointsByUser.containsKey(userId)) {
        await controller!.removeSymbol(symbolsByUser[userId]!);
        symbolsByUser.remove(userId);
      }
    }

    for (final userId in trailsLinesByUser.keys) {
      if (!pointsByUser.containsKey(userId)) {
        for (final line in trailsLinesByUser[userId]!) {
          await controller!.removeLine(line);
        }
        trailsLinesByUser.remove(userId);
      }
    }

    // move camera to new bounds
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
