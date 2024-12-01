import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/instance.dart';

class CreateEventScreen extends ConsumerWidget {
  const CreateEventScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasBannerPhoto = context.knobs.boolean(
      label: 'Has banner photo',
      initial: false,
      description: 'Toggle banner photo state',
    );

    return AppScaffold(
      title: 'Create Event',
      body: CustomScrollView(
        slivers: [
          // Banner Photo Section
          SliverToBoxAdapter(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: hasBannerPhoto
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://picsum.photos/800/400',
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filledTonal(
                            onPressed: () {},
                            icon: const Icon(Icons.edit),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 56,
                          child: IconButton.filledTonal(
                            onPressed: () {},
                            icon: const Icon(Icons.delete),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                      ),
                      child: const Center(
                        child: Icon(Icons.add_photo_alternate, size: 48),
                      ),
                    ),
            ),
          ),

          // Form Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Info Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basic Information',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Event Title',
                              hintText: 'What\'s happening?',
                              prefixIcon: Icon(Icons.event),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Activity Type',
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'hiking',
                                child: Text('Hiking'),
                              ),
                              DropdownMenuItem(
                                value: 'board_games',
                                child: Text('Board Games'),
                              ),
                            ],
                            onChanged: (value) {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date & Time Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'When',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('Date'),
                            trailing: const Text('Select'),
                            onTap: () {},
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.access_time),
                            title: const Text('Start Time'),
                            trailing: const Text('Select'),
                            onTap: () {},
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.access_time),
                            title: const Text('End Time'),
                            trailing: const Text('Select'),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Where',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Location Name',
                              hintText: 'e.g., Central Park, Joe\'s Coffee',
                              prefixIcon: Icon(Icons.place),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('Select on Map'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Details Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Additional Details',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'Add any important details...',
                              prefixIcon: Icon(Icons.description),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Event Link (optional)',
                              hintText: 'https://',
                              prefixIcon: Icon(Icons.link),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Visibility Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Who Can See This?',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          RadioListTile<InstanceVisibility>(
                            title: const Text('Public'),
                            subtitle:
                                const Text('Anyone can discover this event'),
                            value: InstanceVisibility.public,
                            groupValue: InstanceVisibility.public,
                            onChanged: (value) {},
                          ),
                          RadioListTile<InstanceVisibility>(
                            title: const Text('Friends Only'),
                            subtitle: const Text(
                                'Only your friends will see this event'),
                            value: InstanceVisibility.friends,
                            groupValue: InstanceVisibility.public,
                            onChanged: (value) {},
                          ),
                          RadioListTile<InstanceVisibility>(
                            title: const Text('Private'),
                            subtitle: const Text(
                                'Only people you invite will see this event'),
                            value: InstanceVisibility.private,
                            groupValue: InstanceVisibility.public,
                            onChanged: (value) {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Create Event'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
