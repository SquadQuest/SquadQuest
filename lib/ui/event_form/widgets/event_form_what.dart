import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/components/pickers/topic.dart';

/// Event details section for event form.
///
/// Displays a card with form fields for:
/// - Event title
/// - Event topic
/// - Event link (optional)
/// - Event description (optional)
class EventFormWhat extends ConsumerWidget {
  const EventFormWhat({
    super.key,
    required this.titleController,
    required this.topicProvider,
    required this.linkController,
    required this.notesController,
    required this.visibilityProvider,
  });

  final TextEditingController titleController;
  final StateProvider<Topic?> topicProvider;
  final TextEditingController linkController;
  final TextEditingController notesController;
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
              'What',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Event Title',
                hintText: 'What\'s happening?',
                prefixIcon: const Icon(Icons.title),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha(80),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter event title';
                }
                return null;
              },
              controller: titleController,
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final visibility = ref.watch(visibilityProvider);
                return FormTopicPicker(
                  valueProvider: topicProvider,
                  required: visibility != InstanceVisibility.private,
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.url],
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Event Link (optional)',
                hintText: 'https://',
                prefixIcon: const Icon(Icons.link),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha(80),
              ),
              controller: linkController,
              validator: (value) {
                if (value != null &&
                    value.isNotEmpty &&
                    !RegExp(r'^https?://', caseSensitive: false)
                        .hasMatch(value)) {
                  return 'Link must start with http:// or https://';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add any important details...',
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.description),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha(80),
              ),
              controller: notesController,
            ),
          ],
        ),
      ),
    );
  }
}
