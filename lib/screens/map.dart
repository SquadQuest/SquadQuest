import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/drawer.dart';
import 'package:squadquest/models/location_point.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/components/base_map.dart';
import 'package:squadquest/controllers/settings.dart';

// Providers for threshold values (stored in meters, converted to degrees when used)
final minSinglePointBoundsProvider = StateProvider<double>((ref) => 500);
final minMultiPointBoundsProvider = StateProvider<double>((ref) => 100);
final maxDistanceProvider = StateProvider<double>((ref) => 500);
final segmentThresholdProvider = StateProvider<double>((ref) => 10);
final zigzagRadiusProvider = StateProvider<double>((ref) => 30);
final autoCameraEnabledProvider = StateProvider<bool>((ref) => true);

class MapScreen extends BaseMap {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends BaseMapState<MapScreen> {
  // Convert meters to degrees by dividing by 111000
  @override
  double get minSinglePointBounds =>
      ref.watch(minSinglePointBoundsProvider) / 111000;

  @override
  double get minMultiPointBounds =>
      ref.watch(minMultiPointBoundsProvider) / 111000;

  @override
  double get maxSegmentDistance => ref.watch(maxDistanceProvider) / 111000;

  @override
  double get segmentThreshold => ref.watch(segmentThresholdProvider) / 111000;

  @override
  double get zigzagRadius => ref.watch(zigzagRadiusProvider) / 111000;

  @override
  bool get autoCameraEnabled => ref.watch(autoCameraEnabledProvider);

  @override
  void initState() {
    super.initState();
    // Set up listeners for threshold changes
    ref.listenManual(
        minSinglePointBoundsProvider, (_, __) => _onThresholdChange());
    ref.listenManual(
        minMultiPointBoundsProvider, (_, __) => _onThresholdChange());
    ref.listenManual(maxDistanceProvider, (_, __) => _onThresholdChange());
    ref.listenManual(segmentThresholdProvider, (_, __) => _onThresholdChange());
    ref.listenManual(zigzagRadiusProvider, (_, __) => _onThresholdChange());
  }

  void _onThresholdChange() {
    // Force a re-render of trails with current points
    if (points != null && points!.isNotEmpty) {
      // Create a new list to ensure change detection
      renderTrails(List<LocationPoint>.from(points!));
    }
  }

  @override
  Future<void> loadTrails() async {
    final supabase = ref.read(supabaseClientProvider);

    subscription = supabase
        .from('location_points')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .listen((data) {
          final List<LocationPoint> points =
              data.map(LocationPoint.fromMap).toList();

          renderTrails(points);
        });
  }

  void _showDevMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => const DevMenu(),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showDevMenu = ref.watch(developerModeProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends Map'),
          actions: [
            if (showDevMenu)
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _showDevMenu,
              ),
          ],
        ),
        drawer: const AppDrawer(),
        body: buildMap(),
      ),
    );
  }
}

class DevMenu extends ConsumerWidget {
  const DevMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoCameraEnabled = ref.watch(autoCameraEnabledProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Developer Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: autoCameraEnabled,
                onChanged: (value) {
                  ref.read(autoCameraEnabledProvider.notifier).state =
                      value ?? true;
                },
              ),
              const Text('Auto Camera Enabled'),
            ],
          ),
          const Divider(),
          _buildSlider(
            ref,
            'Min Single Point Bounds (meters)',
            minSinglePointBoundsProvider,
            0,
            1000,
          ),
          _buildSlider(
            ref,
            'Min Multi Point Bounds (meters)',
            minMultiPointBoundsProvider,
            0,
            500,
          ),
          _buildSlider(
            ref,
            'Max Segment Distance (meters)',
            maxDistanceProvider,
            0,
            1000,
          ),
          _buildSlider(
            ref,
            'Segment Threshold (meters)',
            segmentThresholdProvider,
            0,
            100,
          ),
          _buildSlider(
            ref,
            'Zigzag Radius (meters)',
            zigzagRadiusProvider,
            0,
            200,
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    WidgetRef ref,
    String label,
    StateProvider<double> provider,
    double min,
    double max,
  ) {
    final value = ref.watch(provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: (newValue) {
                  ref.read(provider.notifier).state = newValue;
                },
              ),
            ),
            Text('${value.toStringAsFixed(1)}m'),
          ],
        ),
      ],
    );
  }
}
