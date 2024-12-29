import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/controllers/calendar.dart';

class SettingsPrivacySection extends ConsumerWidget {
  const SettingsPrivacySection({super.key});

  Future<void> _showAlert(
      BuildContext context, String title, String body) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationSharingEnabled = ref.watch(locationSharingEnabledProvider);
    final calendarWritingEnabled = ref.watch(calendarWritingEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: Row(
            children: [
              Icon(
                Icons.security_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Privacy & Integration',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              ListTile(
                title: const Text('Location Sharing'),
                subtitle: const Text('Share your location during live events'),
                leading: Icon(
                  Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: Switch(
                  value: locationSharingEnabled ?? false,
                  onChanged: (value) {
                    ref.read(locationSharingEnabledProvider.notifier).state =
                        value;
                  },
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                title: const Text('Calendar Sync'),
                subtitle:
                    const Text('Add events you\'re attending to your calendar'),
                leading: Icon(
                  Icons.calendar_month_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: Switch(
                  value: calendarWritingEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final permissionGranted =
                          await CalendarController.instance.requestPermission();

                      if (!permissionGranted) {
                        if (!context.mounted) return;
                        await _showAlert(
                          context,
                          'Calendar permission required',
                          'It looks like you\'ve denied SquadQuest\'s permission to access your calendar.\n\n'
                              'To enable it now, you\'ll need to manually go into your device settings and enable the calendar permission for SquadQuest.',
                        );
                        value = false;
                      }
                    }

                    if (value && Platform.isAndroid) {
                      if (!context.mounted) return;
                      await _showAlert(
                        context,
                        'Enabling SquadQuest Calendar',
                        'On Android, an additional manual step is required before you\'ll see SquadQuest events on your calendar:\n\n'
                            '1. Open your Google Calendar app\n'
                            '2. Tap the three lines in the top left corner\n'
                            '3. Scroll down and tap "Settings"\n'
                            '4. Tap "Manage accounts"\n'
                            '5. Enable the "SquadQuest" account\n',
                      );
                    }

                    ref.read(calendarWritingEnabledProvider.notifier).state =
                        value;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
