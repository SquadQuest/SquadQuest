import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squad_quest/controllers/home.dart';
import 'package:squad_quest/controllers/auth.dart';
import 'package:squad_quest/components/instance_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final instancesList = ref.watch(instancesListProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Welcome to SquadQuest'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                context.push('/settings');
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                  'Logged in as ${user?.userMetadata!['first_name']} ${user?.userMetadata!['last_name']}'),
              Expanded(
                child: instancesList.when(
                    data: (instances) {
                      return ListView.builder(
                        itemCount: instances.length,
                        itemBuilder: (context, index) {
                          return InstanceTile(instance: instances[index]);
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) =>
                        Center(child: Text('Error: $error'))),
              ),
              Center(
                  child: ElevatedButton(
                child: const Text('Refresh'),
                onPressed: () {
                  ref.read(instancesListProvider.notifier).refresh();
                },
              ))
            ],
          ),
        ),
      ),
    );
  }
}
