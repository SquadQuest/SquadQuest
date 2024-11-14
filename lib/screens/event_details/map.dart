import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/controllers/instances.dart';

class EventDetailsMap extends ConsumerStatefulWidget {
  final Instance event;
  final InstanceID instanceId;
  final Function() onShowRallyPointMap;

  const EventDetailsMap({
    super.key,
    required this.event,
    required this.instanceId,
    required this.onShowRallyPointMap,
  });

  @override
  ConsumerState<EventDetailsMap> createState() => _EventDetailsMapState();
}

class _EventDetailsMapState extends ConsumerState<EventDetailsMap> {
  MapLibreMapController? _controller;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  void _onStyleLoaded(Instance event) async {
    await _controller!.addImage(
        'flag-marker',
        (await rootBundle.load('assets/symbols/flag-marker.png'))
            .buffer
            .asUint8List());

    // Add rally point if exists
    if (event.rallyPoint != null) {
      final latLng = LatLng(event.rallyPoint!.lat, event.rallyPoint!.lon);
      await _controller!.addSymbol(
        SymbolOptions(
          geometry: latLng,
          iconImage: 'flag-marker',
          iconSize: kIsWeb ? 0.125 : 0.25,
          iconAnchor: 'bottom-left',
        ),
      );
      await _controller!.animateCamera(CameraUpdate.newLatLng(latLng));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (_, ref, child) {
      final eventPointsAsync =
          ref.watch(eventPointsProvider(widget.instanceId));
      final mapCenter =
          eventPointsAsync.value?.centroid ?? widget.event.rallyPoint;

      if (mapCenter == null) {
        return const SizedBox.shrink();
      }

      return AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            MapLibreMap(
              styleString:
                  'https://api.maptiler.com/maps/08847b31-fc27-462a-b87e-2e8d8a700529/style.json?key=XYHvSt2RxwZPOxjSj98n',
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: () => _onStyleLoaded(widget.event),
              gestureRecognizers: null,
              dragEnabled: false,
              compassEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              scrollGesturesEnabled: false,
              doubleClickZoomEnabled: false,
              attributionButtonPosition: AttributionButtonPosition.bottomRight,
              attributionButtonMargins: const Point(-100, -100),
              initialCameraPosition: CameraPosition(
                target: LatLng(mapCenter.lat, mapCenter.lon),
                zoom: 11.75,
              ),
            ),
            const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.zoom_in,
                  size: 32,
                )),
            eventPointsAsync.when(
              data: (eventPoints) =>
                  eventPoints == null || eventPoints.users == 0
                      ? const SizedBox.shrink()
                      : Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                              color: Colors.black.withOpacity(0.5),
                              child: Text(
                                '${eventPoints.users} live ${eventPoints.users == 1 ? 'user' : 'users'}',
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                              ))),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            InkWell(
              onTap: widget.onShowRallyPointMap,
            )
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}
