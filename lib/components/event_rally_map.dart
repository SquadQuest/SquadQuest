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

class EventRallyMap extends ConsumerStatefulWidget {
  final String title;
  final LatLng mapCenter;
  final Geographic? initialRallyPoint;

  const EventRallyMap(
      {super.key,
      this.title = 'Set rally point',
      this.mapCenter = const LatLng(39.9550, -75.1605),
      this.initialRallyPoint});

  @override
  ConsumerState<EventRallyMap> createState() => _EventRallyMapState();
}

class _EventRallyMapState extends ConsumerState<EventRallyMap> {
  MapLibreMapController? controller;
  late LatLng rallyPoint;
  Symbol? dragSymbol;
  FocusNode searchFocus = FocusNode();
  List<Symbol> resultSymbols = [];

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

    final mediaQueryData = MediaQuery.of(context);
    final displayFeaturesHeight = View.of(context)
        .displayFeatures
        .map((displayFeature) => displayFeature.bounds.height)
        .fold(0.0, (value, height) => value + height);

    return Container(
        height: searchFocus.hasFocus
            ? mediaQueryData.size.height -
                mediaQueryData.viewPadding.vertical -
                displayFeaturesHeight
            : mediaQueryData.size.height * .80,
        padding: mediaQueryData.viewInsets,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Stack(alignment: Alignment.center, children: [
            Positioned(
                left: 12,
                child: IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: () {
                      Navigator.of(context).pop(rallyPointGeographic);
                    })),
            Positioned(
                right: 12,
                child: PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    offset: const Offset(0, 50),
                    itemBuilder: (BuildContext context) => [
                          PopupMenuItem(
                            child: const ListTile(
                              leading: Icon(Icons.save),
                              title: Text('Save rally point'),
                            ),
                            onTap: () {
                              Navigator.of(context).pop(rallyPointGeographic);
                            },
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
                              Navigator.of(context)
                                  .pop(widget.initialRallyPoint);
                            },
                          ),
                        ])),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ]),
          TextField(
            focusNode: searchFocus,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Search locations',
            ),
            onSubmitted: _onSearch,
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
          )),
        ]));
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

  _onFeatureDrag(dynamic id,
      {required Point<double> point,
      required LatLng origin,
      required LatLng current,
      required LatLng delta,
      required DragEventType eventType}) {
    if (eventType != DragEventType.end) {
      return;
    }

    rallyPoint = dragSymbol!.options.geometry!;
  }

  _onSymbolTapped(Symbol resultSymbol) async {
    rallyPoint = resultSymbol.options.geometry!;

    await controller!.removeSymbols(resultSymbols);
    await controller!.updateSymbol(
        dragSymbol!, SymbolOptions(geometry: resultSymbol.options.geometry));
  }

  _onSearch(String search) async {
    // clear any previous results
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

  @override
  void dispose() {
    controller?.onFeatureDrag.remove(_onFeatureDrag);
    controller?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
  }
}
