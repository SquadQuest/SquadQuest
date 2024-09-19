import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/controllers/location.dart';
import 'package:squadquest/models/instance.dart';

class LocationSharingSheet extends ConsumerWidget {
  final InstanceID? locationSharingAvailableEvent;

  const LocationSharingSheet({super.key, this.locationSharingAvailableEvent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO / FIXME: restore some kind of colors here
    // final squadQuestTheme = Theme.of(context).extension<SquadQuestColors>()!;
    final locationSharing = ref.watch(locationSharingProvider);

    if (locationSharing == false && locationSharingAvailableEvent == null) {
      return const SizedBox.shrink();
    }

    return BottomSheet(
        enableDrag: false,
        // backgroundColor: locationSharing == false
        //     ? squadQuestTheme.locationSharingBottomSheetAvailableBackgroundColor
        //     : squadQuestTheme.locationSharingBottomSheetActiveBackgroundColor,
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
                        : locationSharing == false
                            ? 'Your location is not currently being shared'
                            : 'Initializing location sharing...',
                    textAlign: TextAlign.center,
                    // style: squadQuestTheme.locationSharingBottomSheetTextStyle,
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
                    : locationSharing == false
                        ? ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(locationControllerProvider)
                                  .startTracking(locationSharingAvailableEvent);
                            },
                            child: const Text('Start'),
                          )
                        : const CircularProgressIndicator()
              ],
            )));
  }
}
