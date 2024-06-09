import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/controllers/auth.dart';
import 'package:squad_quest/src/settings/settings_view.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  static const routeName = '/home';

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Welcome to SquadQuest'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // Navigate to the settings page. If the user leaves and returns
                // to the app after it has been killed while running in the
                // background, the navigation stack is restored.
                Navigator.restorablePushNamed(context, SettingsView.routeName);
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                  'Logged in as ${user?.userMetadata!['first_name']} ${user?.userMetadata!['last_name']}')
            ],
          ),
        ),
      ),
    );
  }
}
