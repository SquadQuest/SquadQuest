import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geobase/coordinates.dart';

class MapPreview extends StatefulWidget {
  final Geographic location;
  final VoidCallback? onTap;
  final String? overlayText;

  const MapPreview({
    super.key,
    required this.location,
    this.onTap,
    this.overlayText,
  });

  @override
  State<MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<MapPreview> {
  MapLibreMapController? _mapController;
  Symbol? _locationSymbol;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapLibreMap(
          styleString:
              'https://api.maptiler.com/maps/08847b31-fc27-462a-b87e-2e8d8a700529/style.json?key=XYHvSt2RxwZPOxjSj98n',
          onMapCreated: (controller) {
            _mapController = controller;
            controller.addSymbol(SymbolOptions(
                geometry: LatLng(widget.location.lat, widget.location.lon),
                iconImage: 'flag-marker',
                iconSize: kIsWeb ? 0.125 : 0.25,
                iconAnchor: 'bottom-left'));
          },

          // disable all interaction
          gestureRecognizers: null,
          dragEnabled: false,
          compassEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          scrollGesturesEnabled: false,
          doubleClickZoomEnabled: false,

          // hide attribution in mini view
          attributionButtonPosition: AttributionButtonPosition.bottomRight,
          attributionButtonMargins: const Point(-100, -100),

          // set initial camera position
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.location.lat, widget.location.lon),
            zoom: 11.75,
          ),
        ),
        const Positioned(
          top: 0,
          right: 0,
          child: Icon(
            Icons.zoom_in,
            size: 32,
          ),
        ),
        if (widget.overlayText != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withAlpha(130),
              child: Text(
                widget.overlayText!,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
            ),
          ),
        ),
      ],
    );
  }
}
