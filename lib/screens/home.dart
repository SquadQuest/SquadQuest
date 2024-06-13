import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grouped_list/grouped_list.dart';

import 'package:squad_quest/drawer.dart';
import 'package:squad_quest/controllers/instances.dart';
import 'package:squad_quest/components/tiles/instance.dart';
import 'package:squad_quest/models/instance.dart';

enum _InstanceGroup {
  current,
  upcoming,
  past,
}

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
            context.push('/post-event');
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
                final now = DateTime.now();

                return GroupedListView(
                  elements: instances,
                  physics: const AlwaysScrollableScrollPhysics(),
                  useStickyGroupSeparators: true,
                  // floatingHeader: true,
                  stickyHeaderBackgroundColor:
                      Theme.of(context).scaffoldBackgroundColor,
                  groupBy: (Instance instance) =>
                      instance.startTimeMax.isBefore(now)
                          ? _InstanceGroup.past
                          : _InstanceGroup.upcoming,
                  groupComparator: (group1, group2) {
                    return group1.index.compareTo(group2.index);
                  },
                  groupSeparatorBuilder: (_InstanceGroup group) => Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        switch (group) {
                          _InstanceGroup.past => 'In the past',
                          _InstanceGroup.current => 'Happening now',
                          _InstanceGroup.upcoming => 'Coming up',
                        },
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      )),
                  itemBuilder: (context, instance) {
                    return InstanceTile(
                        instance: instance,
                        onTap: () {
                          context.push('/events/${instance.id}');
                        });
                  },
                  itemComparator: (instance1, instance2) {
                    // sort past events in reverse chronological order
                    if (instance1.startTimeMax.isBefore(now) &&
                        instance2.startTimeMax.isBefore(now)) {
                      return instance2.startTimeMax
                          .compareTo(instance1.startTimeMax);
                    }

                    // sort current/upcoming events in chronological order
                    return instance1.startTimeMax
                        .compareTo(instance2.startTimeMax);
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
