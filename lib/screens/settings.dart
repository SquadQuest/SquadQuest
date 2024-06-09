import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squad_quest/controllers/auth.dart';
import 'package:squad_quest/controllers/settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
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
              const Spacer(flex: 1),
              Center(
                  child: ElevatedButton(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();

                  if (!context.mounted) return;

                  context.go('/login');
                },
                child: const Text(
                  'Sign out',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ))
            ])),
      ),
    );
  }
}
