import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/location_point.dart';

import 'package:squadquest/ui/core/widgets/app_bottom_sheet.dart';
import 'package:squadquest/ui/core/widgets/base_map.dart';

enum Menu { keepRallyPointInView, keepFriendsInView }

final keepRallyPointInViewProvider = StateProvider<bool>((ref) => true);
final keepFriendsInViewProvider = StateProvider<bool>((ref) => true);

class EventLiveMap extends BaseMap {
  final String title;
  final InstanceID eventId;
  final double? height;
  final LatLng? rallyPoint;

  const EventLiveMap({
    super.key,
    this.title = 'Live map',
    required this.eventId,
    this.height,
    this.rallyPoint,
  });

  @override
  ConsumerState<EventLiveMap> createState() => _EventLiveMapState();
}

class _EventLiveMapState extends BaseMapState<EventLiveMap> {
  @override
  bool get keepTrailsInView => ref.read(keepFriendsInViewProvider);

  @override
  Future<void> loadAdditionalMarkers() async {
    await controller!.addImage(
        'flag-marker',
        (await rootBundle.load('assets/symbols/flag-marker.png'))
            .buffer
            .asUint8List());

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

    return AppBottomSheet(
      height: widget.height,
      title: widget.title,
      divider: false,
      bottomPaddingSafeArea: false,
      leftWidget: PopupMenuButton<Menu>(
        icon: const Icon(Icons.more_vert),
        offset: const Offset(0, 50),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<Menu>>[
          CheckedPopupMenuItem<Menu>(
            value: Menu.keepRallyPointInView,
            checked: keepRallyPointInView,
            child: const Text('Keep rally point in view'),
            onTap: () {
              ref.read(keepRallyPointInViewProvider.notifier).state =
                  !keepRallyPointInView;
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
        ],
      ),
      children: [
        Expanded(child: buildMap()),
      ],
    );
  }
}
