import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/services/location.dart';

class LocationSharingSheet extends ConsumerWidget {
  const LocationSharingSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationSharing = ref.watch(locationSharingProvider);

    if (locationSharing == false) {
      return const SizedBox.shrink();
    }

    return Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Icon(Icons.location_on),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                locationSharing == true
                    ? 'Your location is currently being shared with your friends.'
                    : 'Initializing location sharing...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            locationSharing == true
                ? ElevatedButton(
                    onPressed: () {
                      ref.read(locationServiceProvider).stopTracking();
                    },
                    child: const Text('Stop'),
                  )
                : const CircularProgressIndicator()
          ],
        ));
  }
}
