import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/location_point.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/components/base_map.dart';
import 'package:squadquest/controllers/settings.dart';

// Providers for threshold values (stored in meters, converted to degrees when used)
final minSinglePointBoundsProvider = StateProvider<double>((ref) => 500);
final minMultiPointBoundsProvider = StateProvider<double>((ref) => 100);
final maxDistanceProvider = StateProvider<double>((ref) => 500);
final segmentThresholdProvider = StateProvider<double>((ref) => 200);
final zigzagRadiusProvider = StateProvider<double>((ref) => 30);
final largeGapThresholdProvider = StateProvider<double>(
    (ref) => 1000); // New provider for large gap threshold
final autoCameraEnabledProvider = StateProvider<bool>((ref) => true);

// New providers for filtering toggles
final pointZigzagFilterEnabledProvider = StateProvider<bool>((ref) => true);
final largeGapFilterEnabledProvider = StateProvider<bool>((ref) => true);
final solidLineRenderingEnabledProvider = StateProvider<bool>((ref) => false);
final disableSegmentingEnabledProvider = StateProvider<bool>((ref) => false);

class MapScreen extends BaseMap {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends BaseMapState<MapScreen> {
  bool _isInitialLoad = true;

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
  double get largeGapThreshold =>
      ref.watch(largeGapThresholdProvider) /
      111000; // New getter for large gap threshold

  @override
  bool get autoCameraEnabled => ref.watch(autoCameraEnabledProvider);

  // New getters for filter toggles
  @override
  bool get pointZigzagFilterEnabled =>
      ref.watch(pointZigzagFilterEnabledProvider);

  @override
  bool get largeGapFilterEnabled => ref.watch(largeGapFilterEnabledProvider);

  @override
  bool get solidLineRenderingEnabled =>
      ref.watch(solidLineRenderingEnabledProvider);

  @override
  bool get disableSegmentingEnabled =>
      ref.watch(disableSegmentingEnabledProvider);

  @override
  Widget build(BuildContext context) {
    final showDevMenu = ref.watch(developerModeProvider);

    // Set up listeners for all providers that should trigger trail updates
    ref.listen(minSinglePointBoundsProvider, (_, __) => _onThresholdChange());
    ref.listen(minMultiPointBoundsProvider, (_, __) => _onThresholdChange());
    ref.listen(maxDistanceProvider, (_, __) => _onThresholdChange());
    ref.listen(segmentThresholdProvider, (_, __) => _onThresholdChange());
    ref.listen(zigzagRadiusProvider, (_, __) => _onThresholdChange());
    ref.listen(
        largeGapThresholdProvider,
        (_, __) =>
            _onThresholdChange()); // New listener for large gap threshold
    ref.listen(
        pointZigzagFilterEnabledProvider, (_, __) => _onThresholdChange());
    ref.listen(largeGapFilterEnabledProvider, (_, __) => _onThresholdChange());
    ref.listen(
        solidLineRenderingEnabledProvider, (_, __) => _onThresholdChange());
    ref.listen(
        disableSegmentingEnabledProvider, (_, __) => _onThresholdChange());

    return AppScaffold(
      title: 'Friends Map',
      loadMask: _isInitialLoad ? 'Loading map data...' : null,
      actions: [
        if (showDevMenu)
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showDevMenu,
          ),
      ],
      body: buildMap(),
    );
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

          if (_isInitialLoad && mounted) {
            setState(() {
              _isInitialLoad = false;
            });
          }
        });
  }

  void _showDevMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => const DevMenu(),
      isScrollControlled: true,
    );
  }
}

class DevMenu extends ConsumerWidget {
  const DevMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoCameraEnabled = ref.watch(autoCameraEnabledProvider);
    final pointZigzagEnabled = ref.watch(pointZigzagFilterEnabledProvider);
    final largeGapEnabled = ref.watch(largeGapFilterEnabledProvider);
    final solidLineEnabled = ref.watch(solidLineRenderingEnabledProvider);
    final disableSegmenting = ref.watch(disableSegmentingEnabledProvider);

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
          const Text('Filtering Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Checkbox(
                value: solidLineEnabled,
                onChanged: (value) {
                  ref.read(solidLineRenderingEnabledProvider.notifier).state =
                      value ?? false;
                },
              ),
              const Text('Solid Line Rendering'),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: disableSegmenting,
                onChanged: (value) {
                  ref.read(disableSegmentingEnabledProvider.notifier).state =
                      value ?? false;
                },
              ),
              const Text('Disable Segmenting'),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: pointZigzagEnabled,
                onChanged: (value) {
                  ref.read(pointZigzagFilterEnabledProvider.notifier).state =
                      value ?? true;
                },
              ),
              const Text('Point-level Zigzag Filter'),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: largeGapEnabled,
                onChanged: (value) {
                  ref.read(largeGapFilterEnabledProvider.notifier).state =
                      value ?? true;
                },
              ),
              const Text('Large Gap Filter'),
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
            500,
          ),
          _buildSlider(
            ref,
            'Zigzag Radius (meters)',
            zigzagRadiusProvider,
            0,
            200,
          ),
          _buildSlider(
            ref,
            'Large Gap Threshold (meters)',
            largeGapThresholdProvider,
            0,
            2000,
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
            Text(
                '${value.toStringAsFixed(1)}m / ${(value / 111000).toStringAsFixed(5)}°'),
          ],
        ),
      ],
    );
  }
}
