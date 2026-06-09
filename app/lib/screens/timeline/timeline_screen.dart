import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../providers/active_context.dart';
import '../../providers/auth_controller.dart';
import '../../providers/providers.dart';
import '../../repositories/timeline_repository.dart';

/// The active timeline — My Friends or a Squad, per the context selector
/// (specs/behaviors/context-selector.md). The title, feed, and compose destination
/// all derive from `activeContextProvider` (one source of truth). Minimal-functional;
/// polished cards come later.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(activeContextProvider);
    final AsyncValue<TimelinePage> timeline = switch (ctx) {
      FriendsContext() => ref.watch(friendsTimelineProvider),
      SquadContext(:final id) => ref.watch(squadTimelineProvider(id)),
    };
    final title = switch (ctx) {
      FriendsContext() => 'My Friends',
      SquadContext(:final name) => name,
    };
    final emptyText = switch (ctx) {
      FriendsContext() =>
        'No ideas yet.\nWhen a friend shares an idea, it shows up here.',
      SquadContext() => 'No ideas in this squad yet.\nTap + to share one.',
    };

    void refresh() => switch (ctx) {
      FriendsContext() => ref.invalidate(friendsTimelineProvider),
      SquadContext(:final id) => ref.invalidate(squadTimelineProvider(id)),
    };

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          key: const Key('contextSelectorButton'),
          onTap: () => _showContextSelector(context, ref),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          IconButton(
            key: const Key('logoutButton'),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('composeIdeaFab'),
        tooltip: 'New idea',
        onPressed: () => context.push('/ideas/new'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => switch (ctx) {
          FriendsContext() => ref.refresh(friendsTimelineProvider.future),
          SquadContext(:final id) => ref.refresh(
            squadTimelineProvider(id).future,
          ),
        },
        child: timeline.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(
                child: Text(
                  'Couldn\'t load this timeline.\n$e',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: FilledButton(
                  onPressed: refresh,
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 160),
                  Center(
                    key: const Key('timelineEmpty'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(emptyText, textAlign: TextAlign.center),
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

  void _showContextSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Consumer(
        builder: (_, ref, _) {
          final squads = ref.watch(squadsProvider);
          return SafeArea(
            child: ListView(
              key: const Key('contextSelectorSheet'),
              shrinkWrap: true,
              children: [
                const ListTile(
                  dense: true,
                  title: Text(
                    'SWITCH CONTEXT',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  key: const Key('ctx_friends'),
                  leading: const Icon(Icons.group),
                  title: const Text('My Friends'),
                  onTap: () {
                    ref.read(activeContextProvider.notifier).toFriends();
                    Navigator.pop(sheetContext);
                  },
                ),
                const Divider(height: 1),
                ...squads.maybeWhen(
                  data: (list) => list.map(
                    (s) => ListTile(
                      key: Key('ctx_squad_${s.id}'),
                      leading: const Icon(Icons.shield_outlined),
                      title: Text(s.name),
                      subtitle: Text('${s.memberCount} members · ${s.role}'),
                      onTap: () {
                        ref
                            .read(activeContextProvider.notifier)
                            .toSquad(s.id, s.name);
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ),
                  orElse: () => [
                    const ListTile(title: Text('Loading squads…')),
                  ],
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('ctx_new_squad'),
                  leading: const Icon(Icons.add),
                  title: const Text('New squad'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/squads/new');
                  },
                ),
              ],
            ),
          );
        },
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
      onTap: () => context.push('/activity/${a.id}', extra: a),
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
