import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/location.dart';

class LocationSharingSheet extends ConsumerWidget {
  const LocationSharingSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationTracking = ref.watch(locationSharingProvider);

    if (!locationTracking) {
      return const SizedBox.shrink();
    }

    return Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Icon(Icons.location_on),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Your location is currently being shared with your friends.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(locationServiceProvider).stopTracking();
              },
              child: const Text('Stop'),
            )
          ],
        ));
  }
}
