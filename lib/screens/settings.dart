import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:squadquest/controllers/calendar.dart';
import 'package:squadquest/controllers/app_versions.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/components/forms/notifications.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Browser? browser;

  @override
  void initState() {
    super.initState();

    browser = Browser.detectOrNull();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final developerMode = ref.watch(developerModeProvider);
    final locationSharingEnabled = ref.watch(locationSharingEnabledProvider);
    final calendarWritingEnabled = ref.watch(calendarWritingEnabledProvider);
    final packageInfo = ref.watch(currentAppPackageProvider);

    final fcmToken =
        developerMode ? ref.watch(firebaseMessagingTokenProvider) : null;

    return AppScaffold(
      title: 'Settings',
      bodyPadding: const EdgeInsets.all(16),
      body: ListView(children: [
        Text('General', style: Theme.of(context).textTheme.headlineSmall),
        ListTile(
          title: const Text('Theme Mode'),
          trailing: DropdownButton<ThemeMode>(
            value: themeMode,
            onChanged: (ThemeMode? themeMode) {
              ref.read(themeModeProvider.notifier).state = themeMode!;
            },
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('System Theme'),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text('Light Theme'),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text('Dark Theme'),
              )
            ],
          ),
          leading: const Icon(Icons.color_lens),
        ),
        CheckboxListTile(
          title: const Text('Location sharing'),
          value: locationSharingEnabled ?? false,
          onChanged: (bool? locationSharingEnabled) {
            ref.read(locationSharingEnabledProvider.notifier).state =
                locationSharingEnabled;
          },
          secondary: const Icon(Icons.pin_drop),
        ),
        CheckboxListTile(
          title: const Text('Show RSVPd events in calendar'),
          value: calendarWritingEnabled,
          onChanged: (bool? calendarWritingEnabled) async {
            calendarWritingEnabled ??= false;

            if (calendarWritingEnabled) {
              final permissionGranted =
                  await CalendarController.instance.requestPermission();

              if (!permissionGranted) {
                await _showAlert(
                    'Calendar permission required',
                    'It looks like you\'ve denied SquadQuest\'s permission to access your calendar.\n\n'
                        'To enable it now, you\'ll need to manually go into your device settings and enable the calendar permission for SquadQuest.');
                calendarWritingEnabled = false;
              }
            }

            if (calendarWritingEnabled && Platform.isAndroid) {
              await _showAlert(
                  'Enabling SquadQuest Calendar',
                  'On Android, an additional manual step is required before you\'ll see SquadQuest events on your calendar:\n\n'
                      '1. Open your Google Calendar app\n'
                      '2. Tap the three lines in the top left corner\n'
                      '3. Scroll down and tap "Settings"\n'
                      '4. Tap "Manage accounts"\n'
                      '5. Enable the "SquadQuest" account\n');
            }

            ref.read(calendarWritingEnabledProvider.notifier).state =
                calendarWritingEnabled;
          },
          secondary: const Icon(Icons.calendar_today),
        ),
        ListTile(
          title: const Text('Delete Account'),
          leading: const Icon(Icons.delete),
          trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                launchUrl(
                    Uri.parse('https://squadquest.app/request-deletion.html'));
              },
              child:
                  const Text('Request', style: TextStyle(color: Colors.white))),
        ),
        Text('Notifications', style: Theme.of(context).textTheme.headlineSmall),
        const NotificationOptions(),
        Text('Developer', style: Theme.of(context).textTheme.headlineSmall),
        ListTile(
            leading: const Icon(Icons.token),
            title: const Text('App Version'),
            trailing: Text(
                '${packageInfo.value?.version}+${packageInfo.value?.buildNumber}',
                style: const TextStyle(fontSize: 16))),
        CheckboxListTile(
          title: const Text('Developer mode'),
          value: developerMode,
          onChanged: (bool? developerMode) {
            ref.read(developerModeProvider.notifier).state =
                developerMode ?? false;
          },
          secondary: const Icon(Icons.build),
        ),
        if (developerMode) ...[
          ListTile(
            title: const Text('Notification permission'),
            trailing: ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(firebaseMessagingServiceProvider)
                      .requestPermissions();
                },
                child: const Text('Request')),
          ),
          ListTile(
            title: const Text('Shared preferences'),
            trailing: ElevatedButton(
                onPressed: () async {
                  await ref.read(settingsControllerProvider).clear();
                },
                child: const Text('Clear')),
          ),
          ListTile(
            title: const Text('Installer store'),
            trailing:
                Text(packageInfo.value?.installerStore ?? 'Not available'),
          ),
          ListTile(
            title: const Text('Browser name'),
            trailing: Text(browser?.browser ?? 'Not available'),
          ),
          ListTile(
            title: const Text('Browser version'),
            trailing: Text(browser?.version ?? 'Not available'),
          ),
          ListTile(
            title: const Text('FCM Token'),
            subtitle: Text(fcmToken ?? 'Not available',
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  Future<void> _showAlert(title, body) async {
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
}
