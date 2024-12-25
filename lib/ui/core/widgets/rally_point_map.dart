import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/coordinates.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:http/http.dart' as http; // TODO: switch to dio

import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/ui/core/widgets/app_bottom_sheet.dart';

class RallyPointMap extends ConsumerStatefulWidget {
  final String title;
  final LatLng mapCenter;
  final Geographic? initialRallyPoint;
  final Function(String)? onPlaceSelect;

  const RallyPointMap({
    super.key,
    this.title = 'Set rally point',
    this.mapCenter = const LatLng(39.9550, -75.1605),
    this.initialRallyPoint,
    this.onPlaceSelect,
  });

  @override
  ConsumerState<RallyPointMap> createState() => _RallyPointMapState();
}

class _RallyPointMapState extends ConsumerState<RallyPointMap>
    with SingleTickerProviderStateMixin {
  MapLibreMapController? controller;
  late LatLng rallyPoint;
  Symbol? dragSymbol;
  FocusNode searchFocus = FocusNode();
  List<Symbol> resultSymbols = [];
  String? selectedPlaceName;
  bool isDragging = false;
  String? resultText;

  Geographic get rallyPointGeographic =>
      Geographic(lat: rallyPoint.latitude, lon: rallyPoint.longitude);

  @override
  void initState() {
    super.initState();
    rallyPoint = widget.initialRallyPoint == null
        ? widget.mapCenter
        : LatLng(widget.initialRallyPoint!.lat, widget.initialRallyPoint!.lon);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // final mediaQueryData = MediaQuery.of(context);
    // final displayFeaturesHeight = View.of(context)
    //     .displayFeatures
    //     .map((displayFeature) => displayFeature.bounds.height)
    //     .fold(0.0, (value, height) => value + height);

    return AppBottomSheet(
        title: widget.title,
        // height: searchFocus.hasFocus
        //     ? mediaQueryData.size.height -
        //         mediaQueryData.viewPadding.vertical -
        //         displayFeaturesHeight
        //     : mediaQueryData.size.height * .80,
        // padding: mediaQueryData.viewInsets,
        rightWidget: IconButton(
          icon: const Icon(Icons.save),
          onPressed: () => _saveRallyPoint(),
        ),
        leftWidget: PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            offset: const Offset(0, 50),
            itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.save),
                      title: Text('Save rally point'),
                    ),
                    onTap: () => _saveRallyPoint(),
                  ),
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.delete),
                      title: Text('Clear rally point'),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(null);
                    },
                  ),
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.undo),
                      title: Text('Cancel change'),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(widget.initialRallyPoint);
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

  void _onStyleLoadedCallback() async {
    controller!.onFeatureDrag.add(_onFeatureDrag);
    controller!.onSymbolTapped.add(_onSymbolTapped);

    // configure symbols
    await controller!.setSymbolIconAllowOverlap(true);
    await controller!.setSymbolTextAllowOverlap(true);
    await controller!.addImage(
        'drag-marker',
        (await rootBundle.load('assets/symbols/drag-marker.png'))
            .buffer
            .asUint8List());
    await controller!.addImage(
        'select-marker',
        (await rootBundle.load('assets/symbols/select-marker.png'))
            .buffer
            .asUint8List());

    dragSymbol = await controller!.addSymbol(SymbolOptions(
        geometry: rallyPoint,
        iconImage: 'drag-marker',
        iconSize: kIsWeb ? 0.5 : 1,
        iconAnchor: 'top',
        draggable: true));
  }

  void _onMapLongClick(Point<double> point, LatLng coordinates) async {
    if (isDragging) {
      return;
    }

    rallyPoint = coordinates;

    await controller!
        .updateSymbol(dragSymbol!, SymbolOptions(geometry: coordinates));
    selectedPlaceName = null;
  }

  _onFeatureDrag(dynamic id,
      {required Point<double> point,
      required LatLng origin,
      required LatLng current,
      required LatLng delta,
      required DragEventType eventType}) {
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
        dragSymbol!, SymbolOptions(geometry: resultSymbol.options.geometry));

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

  void _saveRallyPoint() {
    if (widget.onPlaceSelect != null && selectedPlaceName != null) {
      widget.onPlaceSelect!(selectedPlaceName!);
    }

    Navigator.of(context).pop(rallyPointGeographic);
  }

  @override
  void dispose() {
    controller?.onFeatureDrag.remove(_onFeatureDrag);
    controller?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
  }
}
