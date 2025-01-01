import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:gpx/gpx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/coordinates.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:http/http.dart' as http; // TODO: switch to dio

import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/ui/core/widgets/app_bottom_sheet.dart';

/// Result type returned by RallyPointMap when saved
class RallyPointMapResult {
  final Geographic? rallyPoint;
  final String? locationDescription;
  final List<Geographic>? trail;

  const RallyPointMapResult({
    this.rallyPoint,
    this.locationDescription,
    this.trail,
  });
}

const _trailBoundsPadding = 50 / 11000;

class RallyPointMap extends ConsumerStatefulWidget {
  final String title;
  final LatLng mapCenter;
  final Geographic? initialRallyPoint;
  final List<Geographic>? initialTrail;
  final Function(List<Geographic>)? onTrailUpload;

  const RallyPointMap({
    super.key,
    this.title = 'Set rally point',
    this.mapCenter = const LatLng(39.9550, -75.1605),
    this.initialRallyPoint,
    this.initialTrail,
    this.onTrailUpload,
  });

  @override
  ConsumerState<RallyPointMap> createState() => _RallyPointMapState();
}

class _RallyPointMapState extends ConsumerState<RallyPointMap>
    with SingleTickerProviderStateMixin {
  MapLibreMapController? controller;
  late LatLng? rallyPoint;
  Symbol? dragSymbol;
  Line? trailLine;
  List<Symbol> trailMarkers = [];
  List<Geographic>? trail;
  FocusNode searchFocus = FocusNode();
  List<Symbol> resultSymbols = [];
  String? selectedPlaceName;
  bool isDragging = false;
  String? resultText;

  Geographic? get rallyPointGeographic => rallyPoint == null
      ? null
      : Geographic(lat: rallyPoint!.latitude, lon: rallyPoint!.longitude);

  @override
  void initState() {
    super.initState();
    rallyPoint = widget.initialRallyPoint == null
        ? null
        : LatLng(widget.initialRallyPoint!.lat, widget.initialRallyPoint!.lon);
    trail = widget.initialTrail;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AppBottomSheet(
        title: widget.title,
        bottomPaddingSafeArea: false,
        rightWidget: IconButton(
          icon: const Icon(Icons.save),
          onPressed: _saveChanges,
        ),
        leftWidget: PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            offset: const Offset(0, 50),
            itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    onTap: _uploadGpxTrail,
                    child: const ListTile(
                      leading: Icon(Icons.upload_file),
                      title: Text('Upload GPX trail'),
                    ),
                  ),
                  if (trail != null)
                    PopupMenuItem(
                      onTap: _clearTrail,
                      child: const ListTile(
                        leading: Icon(Icons.clear),
                        title: Text('Clear trail'),
                      ),
                    ),
                  if (rallyPoint != null)
                    PopupMenuItem(
                      onTap: _clearRallyPoint,
                      child: const ListTile(
                        leading: Icon(Icons.clear),
                        title: Text('Clear rally point'),
                      ),
                    ),
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.undo),
                      title: Text('Cancel changes'),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(null);
                    },
                  ),
                ]),
        children: [
          TextField(
            focusNode: searchFocus,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Search locations',
            ),
            onSubmitted: _onSearch,
          ),
          Expanded(
            child: Stack(children: [
              MapLibreMap(
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoadedCallback,
                onMapLongClick: _onMapLongClick,
                styleString:
                    'https://api.maptiler.com/maps/08847b31-fc27-462a-b87e-2e8d8a700529/style.json?key=XYHvSt2RxwZPOxjSj98n',
                myLocationEnabled: true,
                myLocationRenderMode: MyLocationRenderMode.compass,
                myLocationTrackingMode: MyLocationTrackingMode.tracking,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(39.9550, -75.1605),
                  zoom: 11.75,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: resultText == null ? 0.0 : 1.0,
                  child: Container(
                    color: Colors.blue.shade900,
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      resultText ?? '',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]);
  }

  void _onMapCreated(MapLibreMapController controller) {
    this.controller = controller;
  }

  Future<void> _uploadGpxTrail() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.any,
      // allowedExtensions: ['gpx'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    final gpxString = String.fromCharCodes(file.bytes!);
    final gpx = GpxReader().fromString(gpxString);

    if (gpx.trks.isEmpty || gpx.trks.first.trksegs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No track found in GPX file')),
        );
      }
      return;
    }

    // Get points from first track segment, ensuring non-null coordinates
    final points = gpx.trks.first.trksegs.first.trkpts
        .where((p) => p.lat != null && p.lon != null)
        .map((p) => Geographic(lat: p.lat!, lon: p.lon!))
        .toList();

    if (rallyPoint == null && points.isNotEmpty) {
      rallyPoint = LatLng(points.first.lat, points.first.lon);
      await controller!.updateSymbol(
        dragSymbol!,
        SymbolOptions(
          geometry: rallyPoint,
          iconOpacity: 1,
        ),
      );
    }

    await _updateTrail(points);

    if (widget.onTrailUpload != null) {
      widget.onTrailUpload!(points);
    }
  }

  Future<void> _clearTrail() async {
    await _updateTrail(null);
    if (widget.onTrailUpload != null) {
      widget.onTrailUpload!([]);
    }
  }

  Future<void> _updateTrail(List<Geographic>? newTrail) async {
    // Remove existing trail line and markers
    if (trailLine != null) {
      await controller?.removeLine(trailLine!);
      trailLine = null;
    }
    if (trailMarkers.isNotEmpty) {
      await controller?.removeSymbols(trailMarkers);
      trailMarkers.clear();
    }

    // Add new trail line and markers if points provided
    if (newTrail != null && newTrail.isNotEmpty) {
      // Convert trail points to LatLng
      final points = newTrail.map((p) => LatLng(p.lat, p.lon)).toList();
      trail = newTrail;

      // Add trail line
      trailLine = await controller?.addLine(
        LineOptions(
          geometry: points,
          lineColor: "#1976D2",
          lineWidth: 3,
        ),
      );

      // Add start and end markers
      final startMarker = await controller?.addSymbol(
        SymbolOptions(
          geometry: points.first,
          iconImage: 'start-marker',
          iconSize: kIsWeb ? 0.15 : 0.3,
          iconAnchor: 'bottom',
          iconColor: '#00ff00',
          iconOpacity: 0.9,
          textField: 'Start',
          textColor: '#ffffff',
          textAnchor: 'top',
          textOffset: const Offset(0, 0.5),
        ),
      );
      final endMarker = await controller?.addSymbol(
        SymbolOptions(
          geometry: points.last,
          iconImage: 'end-marker',
          iconSize: kIsWeb ? 0.15 : 0.3,
          iconAnchor: 'bottom',
          iconColor: '#ff0000',
          iconOpacity: 0.9,
          textField: 'End',
          textColor: '#ffffff',
          textAnchor: 'top',
          textOffset: const Offset(0, 0.5),
        ),
      );
      if (startMarker != null) trailMarkers.add(startMarker);
      if (endMarker != null) trailMarkers.add(endMarker);

      // Fit map bounds to include trail
      if (controller != null) {
        // Calculate bounds
        var minLat = points.first.latitude;
        var minLon = points.first.longitude;
        var maxLat = minLat;
        var maxLon = minLon;

        for (final point in points) {
          minLat = min(minLat, point.latitude);
          minLon = min(minLon, point.longitude);
          maxLat = max(maxLat, point.latitude);
          maxLon = max(maxLon, point.longitude);
        }

        final bounds = LatLngBounds(
          southwest: LatLng(
              minLat - _trailBoundsPadding, minLon - _trailBoundsPadding),
          northeast: LatLng(
              maxLat + _trailBoundsPadding, maxLon + _trailBoundsPadding),
        );
        await controller!.animateCamera(CameraUpdate.newLatLngBounds(bounds));
      }
    } else {
      trail = null;
    }
  }

  void _onStyleLoadedCallback() async {
    controller!.onFeatureDrag.add(_onFeatureDrag);
    controller!.onSymbolTapped.add(_onSymbolTapped);

    // configure symbols
    await controller!.setSymbolIconAllowOverlap(true);
    await controller!.setSymbolTextAllowOverlap(true);
    await controller!.addImage(
        'drag-marker',
        (await rootBundle.load('assets/symbols/marker-drag.png'))
            .buffer
            .asUint8List());
    await controller!.addImage(
        'select-marker',
        (await rootBundle.load('assets/symbols/marker-select.png'))
            .buffer
            .asUint8List());
    await controller!.addImage(
      'start-marker',
      (await rootBundle.load('assets/symbols/marker-play.png'))
          .buffer
          .asUint8List(),
      true,
    );
    await controller!.addImage(
      'end-marker',
      (await rootBundle.load('assets/symbols/marker-stop.png'))
          .buffer
          .asUint8List(),
      true,
    );

    dragSymbol = await controller!.addSymbol(SymbolOptions(
      geometry: rallyPoint ?? widget.mapCenter,
      iconImage: 'drag-marker',
      iconSize: kIsWeb ? 0.5 : 1,
      iconAnchor: 'top',
      iconOpacity: rallyPoint == null ? 0.3 : 1,
      draggable: true,
    ));

    // Add initial trail if any
    if (trail != null) {
      await _updateTrail(trail);
    }
  }

  void _clearRallyPoint() async {
    rallyPoint = null;
    await controller!.updateSymbol(
        dragSymbol!,
        SymbolOptions(
          geometry: widget.mapCenter,
          iconOpacity: 0.3,
        ));
    selectedPlaceName = null;
  }

  void _onMapLongClick(Point<double> point, LatLng coordinates) async {
    if (isDragging) {
      return;
    }

    rallyPoint = coordinates;

    await controller!.updateSymbol(
        dragSymbol!,
        SymbolOptions(
          geometry: coordinates,
          iconOpacity: 1,
        ));
    selectedPlaceName = null;
  }

  _onFeatureDrag(dynamic id,
      {required Point<double> point,
      required LatLng origin,
      required LatLng current,
      required LatLng delta,
      required DragEventType eventType}) async {
    if (rallyPoint == null) {
      await controller!.updateSymbol(
          dragSymbol!,
          SymbolOptions(
            iconOpacity: 1,
          ));
    }

    if (eventType == DragEventType.start) {
      isDragging = true;
    }

    if (eventType != DragEventType.end) {
      return;
    }

    rallyPoint = dragSymbol!.options.geometry!;
    selectedPlaceName = null;
    isDragging = false;
  }

  _onSymbolTapped(Symbol resultSymbol) async {
    rallyPoint = resultSymbol.options.geometry!;

    selectedPlaceName = resultSymbol.options.textField!;

    await controller!.removeSymbols(resultSymbols);
    await controller!.updateSymbol(
      dragSymbol!,
      SymbolOptions(
        geometry: resultSymbol.options.geometry,
        iconOpacity: 1,
      ),
    );

    setState(() {
      resultText = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Rally point set to $selectedPlaceName',
          textAlign: TextAlign.center,
        ),
      ));
    }
  }

  _onSearch(String search) async {
    // clear any previous results
    setState(() {
      resultText = null;
    });

    await controller!.removeSymbols(resultSymbols);

    // nothing to do if search is empty
    if (search.trim().isEmpty) {
      return;
    }

    // get region of current map view to search within
    final box = await controller?.getVisibleRegion();

    // search OSM data
    final response = await http.get(Uri(
        scheme: 'https',
        host: 'nominatim.openstreetmap.org',
        path: '/search',
        queryParameters: {
          'format': 'json',
          'q': search.trim(),
          'viewbox':
              '${box!.northeast.longitude},${box.northeast.latitude},${box.southwest.longitude},${box.southwest.latitude}',
          'bounded': '1'
        }));
    final responseData = jsonDecode(response.body);

    setState(() {
      resultText =
          'Found ${responseData.length > 0 ? responseData.length : 'no'} ${responseData.length == 1 ? 'result' : 'results'}';
    });

    // render results
    final List<SymbolOptions> resultSymbolOptions = [];
    for (final result in responseData) {
      resultSymbolOptions.add(SymbolOptions(
          geometry:
              LatLng(double.parse(result['lat']), double.parse(result['lon'])),
          iconImage: 'select-marker',
          iconSize: kIsWeb ? 0.4 : 0.9,
          iconAnchor: 'bottom',
          textField: result['name'],
          textColor: '#ffffff',
          textAnchor: 'top-middle',
          textOffset: const Offset(0, 1),
          textSize: 14));
    }

    resultSymbols = await controller!.addSymbols(resultSymbolOptions);
  }

  void _saveChanges() {
    Navigator.of(context).pop(RallyPointMapResult(
      rallyPoint: rallyPointGeographic,
      locationDescription: selectedPlaceName,
      trail: trail,
    ));
  }

  @override
  void dispose() {
    controller?.onFeatureDrag.remove(_onFeatureDrag);
    controller?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
  }
}
