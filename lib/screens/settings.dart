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
  bool _showNotificationDetails = false;

  @override
  void initState() {
    super.initState();
    browser = Browser.detectOrNull();
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
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
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
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
      body: ListView(
        children: [
          _buildSection(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              ListTile(
                title: const Text('Theme Mode'),
                leading: Icon(
                  themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : themeMode == ThemeMode.dark
                          ? Icons.dark_mode
                          : Icons.brightness_auto,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      ref.read(themeModeProvider.notifier).state = value;
                    }
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
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildSection(
            title: 'Privacy & Integration',
            icon: Icons.security_outlined,
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
                        await _showAlert(
                          'Calendar permission required',
                          'It looks like you\'ve denied SquadQuest\'s permission to access your calendar.\n\n'
                              'To enable it now, you\'ll need to manually go into your device settings and enable the calendar permission for SquadQuest.',
                        );
                        value = false;
                      }
                    }

                    if (value && Platform.isAndroid) {
                      await _showAlert(
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
          _buildSection(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Show Details',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _showNotificationDetails,
                  onChanged: (value) {
                    setState(() => _showNotificationDetails = value);
                  },
                ),
              ],
            ),
            children: [
              NotificationOptions(showDetails: _showNotificationDetails),
            ],
          ),
          _buildSection(
            title: 'Account',
            icon: Icons.account_circle_outlined,
            children: [
              ListTile(
                title: const Text('Delete Account'),
                subtitle:
                    const Text('Permanently delete your account and data'),
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () {
                    launchUrl(Uri.parse(
                        'https://squadquest.app/request-deletion.html'));
                  },
                  child: const Text('Request',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          _buildSection(
            title: 'Developer',
            icon: Icons.code,
            children: [
              ListTile(
                title: const Text('App Version'),
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: Text(
                  '${packageInfo.value?.version}+${packageInfo.value?.buildNumber}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              ListTile(
                title: const Text('Developer Mode'),
                subtitle: const Text('Enable advanced debugging features'),
                leading: Icon(
                  Icons.developer_mode,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: Switch(
                  value: developerMode,
                  onChanged: (value) {
                    ref.read(developerModeProvider.notifier).state = value;
                  },
                ),
              ),
              if (developerMode) ...[
                ListTile(
                  title: const Text('Notification Permission'),
                  leading: Icon(
                    Icons.notifications_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(firebaseMessagingServiceProvider)
                          .requestPermissions();
                    },
                    child: const Text('Request'),
                  ),
                ),
                ListTile(
                  title: const Text('Clear App Data'),
                  subtitle: const Text('Reset all settings and cached data'),
                  leading: Icon(
                    Icons.cleaning_services_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      await ref.read(settingsControllerProvider).clear();
                    },
                    child: const Text('Clear'),
                  ),
                ),
                ListTile(
                  title: const Text('Installer Store'),
                  leading: Icon(
                    Icons.store,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Text(
                      packageInfo.value?.installerStore ?? 'Not available'),
                ),
                ListTile(
                  title: const Text('Browser Name'),
                  leading: Icon(
                    Icons.web,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Text(browser?.browser ?? 'Not available'),
                ),
                ListTile(
                  title: const Text('Browser Version'),
                  leading: Icon(
                    Icons.numbers,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Text(browser?.version ?? 'Not available'),
                ),
                ListTile(
                  title: const Text('FCM Token'),
                  leading: Icon(
                    Icons.token,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  subtitle: Text(
                    fcmToken ?? 'Not available',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAlert(String title, String body) async {
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
