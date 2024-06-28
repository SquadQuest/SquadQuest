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

enum Menu { keepRallyPointInView }

final keepRallyPointInViewProvider = StateProvider<bool>((ref) => true);

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
  static const minSinglePointBounds = .005;
  static const minMultiPointBounds = .001;

  MapLibreMapController? controller;
  final Map<UserID, List<Line>> trailsLinesByUser = {};
  final Map<UserID, Symbol> symbolsByUser = {};
  List<LocationPoint>? lastPoints;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final keepRallyPointInView = ref.watch(keepRallyPointInViewProvider);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SizedBox(
        height: MediaQuery.of(context).size.height * .75,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Stack(alignment: Alignment.center, children: [
            Positioned(
                left: 12,
                child: IconButton(
                    icon: const Icon(Icons.arrow_back), // Your desired icon
                    onPressed: () {
                      Navigator.of(context).pop();
                    })),
            Positioned(
              right: 12,
              child: PopupMenuButton<Menu>(
                  icon: const Icon(Icons.more_vert),
                  offset: const Offset(0, 50),
                  // onSelected: _onMenuSelect,
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<Menu>>[
                        CheckedPopupMenuItem<Menu>(
                          value: Menu.keepRallyPointInView,
                          checked: keepRallyPointInView,
                          child: const Text('Keep rally point in view'),
                          onTap: () {
                            ref
                                .read(keepRallyPointInViewProvider.notifier)
                                .state = !keepRallyPointInView;
                            _renderTrails();
                          },
                        ),
                      ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ]),
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
          iconSize: kIsWeb ? 0.25 : 0.5,
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

  Future<void> _renderTrails([List<LocationPoint>? points]) async {
    final keepRallyPointInView = ref.read(keepRallyPointInViewProvider);

    // render previous points or skip if not available
    if (points == null) {
      if (lastPoints == null) {
        return;
      } else {
        points = lastPoints;
      }
    }
    lastPoints = points;

    // group points by user
    final Map<UserID, List<LocationPoint>> pointsByUser = {};
    for (final point in points!) {
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
    double minLatitude =
        (keepRallyPointInView ? widget.rallyPoint?.latitude : null) ?? 90;
    double maxLatitude =
        (keepRallyPointInView ? widget.rallyPoint?.latitude : null) ?? -90;
    double minLongitude =
        (keepRallyPointInView ? widget.rallyPoint?.longitude : null) ?? 180;
    double maxLongitude =
        (keepRallyPointInView ? widget.rallyPoint?.longitude : null) ?? -180;

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
          iconSize: kIsWeb ? 0.4 : 0.9,
          iconAnchor: 'bottom',
          textField: userProfiles[userId]!.fullName,
          textColor: '#ffffff',
          textAnchor: 'top-left',
          textSize: 14);

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

    // apply minimum bounds
    if (minLatitude == maxLatitude && minLongitude == maxLongitude) {
      // zoom out more from single-point bounds
      minLatitude -= minSinglePointBounds;
      maxLatitude += minSinglePointBounds;
      minLongitude -= minSinglePointBounds;
      maxLongitude += minSinglePointBounds;
    } else {
      final diffLatitude = maxLatitude - minLatitude;
      final diffLongitude = maxLongitude - minLongitude;

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
    // final currentBounds = await controller!.getVisibleRegion();
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
}
