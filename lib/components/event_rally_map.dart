import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/coordinates.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:squadquest/controllers/auth.dart';

enum Menu { revertRallyPoint, clearRallyPoint, saveRallyPoint }

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
                      Navigator.of(context).pop(rallyPointGeographic);
                    })),
            Positioned(
                right: 12,
                child: PopupMenuButton<Menu>(
                    icon: const Icon(Icons.more_vert),
                    offset: const Offset(0, 50),
                    // onSelected: _onMenuSelect,
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<Menu>>[
                          PopupMenuItem<Menu>(
                            value: Menu.saveRallyPoint,
                            child: const ListTile(
                              leading: Icon(Icons.save),
                              title: Text('Save rally point'),
                            ),
                            onTap: () {
                              Navigator.of(context).pop(rallyPointGeographic);
                            },
                          ),
                          PopupMenuItem<Menu>(
                            value: Menu.clearRallyPoint,
                            child: const ListTile(
                              leading: Icon(Icons.delete),
                              title: Text('Clear rally point'),
                            ),
                            onTap: () {
                              Navigator.of(context).pop(null);
                            },
                          ),
                          PopupMenuItem<Menu>(
                            value: Menu.revertRallyPoint,
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
          ))
        ]));
  }

  void _onMapCreated(MapLibreMapController controller) {
    this.controller = controller;
  }

  void _onStyleLoadedCallback() async {
    // configure symbols
    await controller!.setSymbolIconAllowOverlap(true);
    await controller!.setSymbolTextAllowOverlap(true);
    await controller!.addImage(
        'drag-marker',
        (await rootBundle.load('assets/symbols/drag-marker.png'))
            .buffer
            .asUint8List());

    dragSymbol = await controller!.addSymbol(SymbolOptions(
        geometry: rallyPoint,
        iconImage: 'drag-marker',
        iconSize: kIsWeb ? 0.5 : 1,
        iconAnchor: 'top',
        draggable: true));

    controller!.onFeatureDrag.add(_onDrag);
  }

  _onDrag(dynamic id,
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
}
