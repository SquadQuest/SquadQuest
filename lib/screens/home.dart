import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squad_quest/drawer.dart';
import 'package:squad_quest/controllers/instances.dart';
import 'package:squad_quest/components/tiles/instance.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final instancesList = ref.watch(instancesProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Welcome to SquadQuest'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              context.push('/post-event');
            });
          },
          child: const Icon(Icons.add),
        ),
        drawer: const AppDrawer(),
        body: RefreshIndicator(
          onRefresh: () async {
            return ref.read(instancesProvider.notifier).refresh();
          },
          child: instancesList.when(
              data: (instances) {
                return ListView.builder(
                  itemCount: instances.length,
                  itemBuilder: (context, index) {
                    return InstanceTile(instance: instances[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Error: $error'))),
        ),
      ),
    );
  }
}
