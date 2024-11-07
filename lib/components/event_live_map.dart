import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/location_point.dart';
import 'package:squadquest/components/base_map.dart';

enum Menu { keepRallyPointInView, keepFriendsInView }

final keepRallyPointInViewProvider = StateProvider<bool>((ref) => true);
final keepFriendsInViewProvider = StateProvider<bool>((ref) => true);

class EventLiveMap extends BaseMap {
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

class _EventLiveMapState extends BaseMapState<EventLiveMap> {
  @override
  Future<void> loadAdditionalMarkers() async {
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
  }

  @override
  Future<void> loadTrails() async {
    final supabase = ref.read(supabaseClientProvider);

    subscription = supabase
        .from('location_points')
        .stream(primaryKey: ['id'])
        .eq('event', widget.eventId)
        .order('timestamp', ascending: false)
        .listen((data) {
          final List<LocationPoint> points =
              data.map(LocationPoint.fromMap).toList();

          renderTrails(points);
        });
  }

  @override
  Map<String, double> getInitialBounds() {
    final keepRallyPointInView = ref.read(keepRallyPointInViewProvider);

    if (keepRallyPointInView && widget.rallyPoint != null) {
      return {
        'minLatitude': widget.rallyPoint!.latitude,
        'maxLatitude': widget.rallyPoint!.latitude,
        'minLongitude': widget.rallyPoint!.longitude,
        'maxLongitude': widget.rallyPoint!.longitude,
      };
    }

    return super.getInitialBounds();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final keepRallyPointInView = ref.watch(keepRallyPointInViewProvider);
    final keepFriendsInView = ref.watch(keepFriendsInViewProvider);

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
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.of(context).pop();
                    })),
            Positioned(
              right: 12,
              child: PopupMenuButton<Menu>(
                  icon: const Icon(Icons.more_vert),
                  offset: const Offset(0, 50),
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<Menu>>[
                        CheckedPopupMenuItem<Menu>(
                          value: Menu.keepRallyPointInView,
                          checked: keepRallyPointInView,
                          child: const Text('Keep rally point in view'),
                          onTap: () {
                            ref
                                .read(keepRallyPointInViewProvider.notifier)
                                .state = !keepRallyPointInView;
                            renderTrails();
                          },
                        ),
                        CheckedPopupMenuItem<Menu>(
                          value: Menu.keepFriendsInView,
                          checked: keepFriendsInView,
                          child: const Text('Keep friends in view'),
                          onTap: () {
                            ref.read(keepFriendsInViewProvider.notifier).state =
                                !keepFriendsInView;
                            renderTrails();
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
          Expanded(child: buildMap())
        ]));
  }
}
