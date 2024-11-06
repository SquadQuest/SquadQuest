import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/drawer.dart';
import 'package:squadquest/models/location_point.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/components/base_map.dart';

class MapScreen extends BaseMap {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends BaseMapState<MapScreen> {
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Map'),
        ),
        drawer: const AppDrawer(),
        body: buildMap(),
      ),
    );
  }
}
