import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/drawer.dart';
import 'package:squadquest/controllers/settings.dart';
import 'package:squadquest/services/firebase.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Browser browser;

  @override
  void initState() {
    super.initState();

    browser = Browser();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final fcmToken = ref.watch(firebaseMessagingTokenProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        drawer: const AppDrawer(),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButton<ThemeMode>(
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
              const Spacer(),
              Text('Browser name: ${browser.browser}'),
              Text('Browser version ${browser.version}'),
              SizedBox(height: 16),
              Text('FCM token: $fcmToken'),
              SizedBox(height: 16),
              ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(firebaseMessagingServiceProvider)
                        .requestPermissions();
                  },
                  child: const Text('Request notification permission'))
            ])),
      ),
    );
  }
}
