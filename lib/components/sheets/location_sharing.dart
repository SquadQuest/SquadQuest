import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/theme.dart';
import 'package:squadquest/controllers/location.dart';

class LocationSharingSheet extends ConsumerWidget {
  const LocationSharingSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadQuestTheme = Theme.of(context).extension<SquadQuestColors>()!;
    final locationSharing = ref.watch(locationSharingProvider);

    if (locationSharing == false) {
      return const SizedBox.shrink();
    }

    return BottomSheet(
        enableDrag: false,
        backgroundColor:
            squadQuestTheme.locationSharingBottomSheetBackgroundColor,
        onClosing: () {},
        builder: (_) => Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Icon(Icons.location_on),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locationSharing == true
                        ? 'Your location is currently being shared with friends'
                        : 'Initializing location sharing...',
                    textAlign: TextAlign.center,
                    style: squadQuestTheme.locationSharingBottomSheetTextStyle,
                  ),
                ),
                const SizedBox(width: 8),
                locationSharing == true
                    ? ElevatedButton(
                        onPressed: () {
                          ref.read(locationControllerProvider).stopTracking();
                        },
                        child: const Text('Stop'),
                      )
                    : const CircularProgressIndicator()
              ],
            )));
  }
}
