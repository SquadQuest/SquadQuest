import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/activity.dart';
import '../../providers/auth_controller.dart';
import '../../providers/providers.dart';

/// The My Friends timeline (specs/screens/friends-timeline.md). Minimal-functional
/// for this stage: a list of idea/activity tiles; the polished card UI comes later.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(friendsTimelineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Friends'),
        actions: [
          IconButton(
            key: const Key('logoutButton'),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(friendsTimelineProvider.future),
        child: timeline.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(
                child: Text(
                  'Couldn\'t load your timeline.\n$e',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: FilledButton(
                  onPressed: () => ref.invalidate(friendsTimelineProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(
                    key: Key('timelineEmpty'),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'No ideas yet.\nWhen a friend shares an idea, it shows up here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              key: const Key('timelineList'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: page.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _ActivityTile(page.items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile(this.activity);
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final subtitle = a.isConfirmed
        ? [a.confirmedTime, a.confirmedLocation].whereType<String>().join(' · ')
        : 'Idea · ${a.audienceSummary ?? ''}';

    return ListTile(
      leading: CircleAvatar(
        child: Text((a.captainName ?? '?').characters.first),
      ),
      title: Text(
        '${a.captainName ?? 'Someone'} · ${a.activityTypeLabel ?? ''}',
      ),
      subtitle: Text(subtitle),
      trailing: a.isConfirmed
          ? const Icon(Icons.event_available)
          : Text('${a.inCount} in'),
    );
  }
}
