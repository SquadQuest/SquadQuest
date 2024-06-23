import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

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
    final fcmToken = ref.watch(firebaseMessagingTokenProvider);

    return AppScaffold(
      title: 'Settings',
      bodyPadding: const EdgeInsets.all(30),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          title: const Text('Developer mode'),
          value: developerMode,
          onChanged: (bool? developerMode) {
            ref.read(developerModeProvider.notifier).state =
                developerMode ?? false;
          },
          secondary: const Icon(Icons.developer_mode),
        ),
        if (developerMode) ...[
          const Spacer(),
          if (browser != null) ...[
            Text('Browser name: ${browser!.browser}'),
            Text('Browser version ${browser!.version}'),
            const SizedBox(height: 16),
          ],
          Text('FCM token: $fcmToken'),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: () async {
                await ref
                    .read(firebaseMessagingServiceProvider)
                    .requestPermissions();
              },
              child: const Text('Request notification permission'))
        ]
      ]),
    );
  }
}
