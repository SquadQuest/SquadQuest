import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/coordinates.dart';

import 'package:squadquest/ui/core/widgets/rally_point_map.dart';
import 'package:squadquest/components/map_preview.dart';

/// Location selection section for event form.
///
/// Displays a card with:
/// - Map preview/selector
/// - Location name input
class EventFormWhere extends ConsumerWidget {
  const EventFormWhere({
    super.key,
    required this.locationProvider,
    required this.locationDescriptionController,
  });

  final StateProvider<Geographic?> locationProvider;
  final TextEditingController locationDescriptionController;

  Future<void> _showRallyPointPicker(
      BuildContext context, WidgetRef ref) async {
    Geographic? newValue = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: true,
      isDismissible: false,
      builder: (BuildContext context) => RallyPointMap(
        initialRallyPoint: ref.read(locationProvider),
        onPlaceSelect: (placeName) {
          if (locationDescriptionController.text.isEmpty) {
            locationDescriptionController.text = placeName;
          }
        },
      ),
    );

    ref.read(locationProvider.notifier).state = newValue;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Where',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha(80),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final location = ref.watch(locationProvider);

                  if (location != null) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MapPreview(
                        location: location,
                        onTap: () => _showRallyPointPicker(context, ref),
                      ),
                    );
                  }

                  return Material(
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _showRallyPointPicker(context, ref),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select on Map (optional)',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Location Name',
                hintText: 'e.g., Central Park, Joe\'s Coffee',
                prefixIcon: const Icon(Icons.place),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha(80),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter location description';
                }
                return null;
              },
              controller: locationDescriptionController,
            ),
          ],
        ),
      ),
    );
  }
}
