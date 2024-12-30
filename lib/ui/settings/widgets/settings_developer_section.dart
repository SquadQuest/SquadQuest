import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/controllers/app_versions.dart';
import 'package:squadquest/services/firebase.dart';

class SettingsDeveloperSection extends ConsumerStatefulWidget {
  const SettingsDeveloperSection({super.key});

  @override
  ConsumerState<SettingsDeveloperSection> createState() =>
      _SettingsDeveloperSectionState();
}

class _SettingsDeveloperSectionState
    extends ConsumerState<SettingsDeveloperSection> {
  late Browser? browser;

  @override
  void initState() {
    super.initState();
    browser = Browser.detectOrNull();
  }

  @override
  Widget build(BuildContext context) {
    final developerMode = ref.watch(developerModeProvider);
    final packageInfo = ref.watch(currentAppPackageProvider);
    final fcmToken =
        developerMode ? ref.watch(firebaseMessagingTokenProvider) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: Row(
            children: [
              Icon(
                Icons.code,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Developer',
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
              const Divider(height: 1, indent: 16, endIndent: 16),
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
                const Divider(height: 1, indent: 16, endIndent: 16),
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
                const Divider(height: 1, indent: 16, endIndent: 16),
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
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Installer Store'),
                  leading: Icon(
                    Icons.store,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Text(
                      packageInfo.value?.installerStore ?? 'Not available'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Browser Name'),
                  leading: Icon(
                    Icons.web,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Text(browser?.browser ?? 'Not available'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Browser Version'),
                  leading: Icon(
                    Icons.numbers,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Text(browser?.version ?? 'Not available'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
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
        ),
      ],
    );
  }
}
