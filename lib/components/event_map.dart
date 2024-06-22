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

class EventMap extends ConsumerStatefulWidget {
  final String title;
  final InstanceID eventId;

  const EventMap({super.key, this.title = 'Live map', required this.eventId});

  @override
  ConsumerState<EventMap> createState() => _EventMapState();
}

class _EventMapState extends ConsumerState<EventMap> {
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
        child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
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
            ])));
  }

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
    _loadTrails();
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
          iconSize: 0.75,
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
  }
}
