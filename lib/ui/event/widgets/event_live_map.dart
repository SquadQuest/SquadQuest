import 'dart:math';

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
  final List<LatLng>? trail;

  const EventLiveMap({
    super.key,
    this.title = 'Live map',
    required this.eventId,
    this.height,
    this.rallyPoint,
    this.trail,
  });

  @override
  ConsumerState<EventLiveMap> createState() => _EventLiveMapState();
}

class _EventLiveMapState extends BaseMapState<EventLiveMap> {
  @override
  bool get keepTrailsInView => ref.read(keepFriendsInViewProvider);

  @override
  Future<void> loadAdditionalMarkers() async {
    // Load marker images
    await controller!.addImage(
        'flag-marker',
        (await rootBundle.load('assets/symbols/marker-flag.png'))
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

    // Add rally point marker
    if (widget.rallyPoint != null) {
      await controller!.addSymbol(SymbolOptions(
          geometry: widget.rallyPoint,
          iconImage: 'flag-marker',
          iconSize: kIsWeb ? 0.25 : 0.5,
          iconAnchor: 'bottom-left'));
    }

    // Add trail line and markers
    if (widget.trail != null && widget.trail!.isNotEmpty) {
      // Add trail line
      await controller!.addLine(
        LineOptions(
          geometry: widget.trail!,
          lineColor: "#1976D2",
          lineWidth: 3,
        ),
      );

      // Add start marker
      await controller?.addSymbol(
        SymbolOptions(
          geometry: widget.trail!.first,
          iconImage: 'start-marker',
          iconSize: kIsWeb ? 0.15 : 0.3,
          iconAnchor: 'bottom',
          iconColor: '#00ff00',
          textField: 'Start',
          textColor: '#ffffff',
          textAnchor: 'top',
          textOffset: const Offset(0, 0.5),
        ),
      );

      // Add end marker
      await controller?.addSymbol(
        SymbolOptions(
          geometry: widget.trail!.last,
          iconImage: 'end-marker',
          iconSize: kIsWeb ? 0.15 : 0.3,
          iconAnchor: 'bottom',
          iconColor: '#ff0000',
          textField: 'End',
          textColor: '#ffffff',
          textAnchor: 'top',
          textOffset: const Offset(0, 0.5),
        ),
      );
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

    if (keepRallyPointInView) {
      var minLat = double.infinity;
      var minLon = double.infinity;
      var maxLat = -double.infinity;
      var maxLon = -double.infinity;

      // Include rally point in bounds if present
      if (widget.rallyPoint != null) {
        minLat = maxLat = widget.rallyPoint!.latitude;
        minLon = maxLon = widget.rallyPoint!.longitude;
      }

      // Include trail points in bounds if present
      if (widget.trail != null) {
        for (final point in widget.trail!) {
          minLat = min(minLat, point.latitude);
          minLon = min(minLon, point.longitude);
          maxLat = max(maxLat, point.latitude);
          maxLon = max(maxLon, point.longitude);
        }
      }

      // Only return bounds if we have points to bound
      if (minLat != double.infinity) {
        return {
          'minLatitude': minLat,
          'maxLatitude': maxLat,
          'minLongitude': minLon,
          'maxLongitude': maxLon,
        };
      }
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

  @override
  dispose() {
    subscription?.cancel();
    super.dispose();
  }
}
