import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/coordinates.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationDescriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _linkController = TextEditingController();

  final _topicProvider = StateProvider<Topic?>((ref) => null);
  final _locationProvider = StateProvider<Geographic?>((ref) => null);
  final _startTimeMinProvider = StateProvider<TimeOfDay?>((ref) => null);
  final _startTimeMaxProvider = StateProvider<TimeOfDay?>((ref) => null);
  final _visibilityProvider = StateProvider<InstanceVisibility?>((ref) => null);
  final _bannerPhotoProvider = StateProvider<Uri?>((ref) => null);

  DateTime? startDate;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Create Event',
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner Photo Section
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: const Center(
                    child: Icon(Icons.add_photo_alternate, size: 48),
                  ),
                ),
              ),

              // Main Form Content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Info Section
                    _buildSectionTitle('Basic Info'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Event Title',
                                hintText: 'What\'s happening?',
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Activity Type',
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
                    const SizedBox(height: 24),

                    // Date & Time Section
                    _buildSectionTitle('When'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: const Text('Date'),
                              trailing: const Text('Select'),
                              onTap: () {
                                // Show date picker
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.access_time),
                              title: const Text('Start Time'),
                              trailing: const Text('Select'),
                              onTap: () {
                                // Show time picker
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.access_time),
                              title: const Text('End Time'),
                              trailing: const Text('Select'),
                              onTap: () {
                                // Show time picker
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Location Section
                    _buildSectionTitle('Where'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _locationDescriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Location Name',
                                hintText: 'e.g., Central Park, Joe\'s Coffee',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
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
                    const SizedBox(height: 24),

                    // Details Section
                    _buildSectionTitle('Additional Details'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText: 'Add any important details...',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _linkController,
                              decoration: const InputDecoration(
                                labelText: 'Event Link (optional)',
                                hintText: 'https://',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Visibility Section
                    _buildSectionTitle('Who Can See This?'),
                    Card(
                      child: Column(
                        children: [
                          RadioListTile(
                            title: const Text('Friends Only'),
                            subtitle: const Text(
                                'Only your friends will see this event'),
                            value: InstanceVisibility.friends,
                            groupValue: ref.watch(_visibilityProvider),
                            onChanged: (value) {
                              ref.read(_visibilityProvider.notifier).state =
                                  value as InstanceVisibility;
                            },
                          ),
                          RadioListTile(
                            title: const Text('Public'),
                            subtitle:
                                const Text('Anyone can discover this event'),
                            value: InstanceVisibility.public,
                            groupValue: ref.watch(_visibilityProvider),
                            onChanged: (value) {
                              ref.read(_visibilityProvider.notifier).state =
                                  value as InstanceVisibility;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    FilledButton(
                      onPressed: () {
                        // Handle form submission
                      },
                      child: const Text('Create Event'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
