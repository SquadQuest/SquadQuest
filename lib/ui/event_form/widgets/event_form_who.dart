import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/components/pickers/visibility.dart';

/// Visibility selection section for event form.
///
/// Displays a card with visibility picker that allows users to:
/// - Select event visibility (friends, public, private)
class EventFormWho extends ConsumerWidget {
  const EventFormWho({
    super.key,
    required this.visibilityProvider,
  });

  final StateProvider<InstanceVisibility?> visibilityProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Who',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FormVisibilityPicker(
              labelText: '',
              valueProvider: visibilityProvider,
            ),
          ],
        ),
      ),
    );
  }
}
