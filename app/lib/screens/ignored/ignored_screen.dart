import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/friend.dart';
import '../../providers/providers.dart';

/// The Ignored recovery surface (specs/screens/ignored.md): everything the user
/// has ignored — friend requests + want invites — with un-ignore to restore. The
/// reversibility half of the dismissal-is-silent-and-reversible principle. Usually
/// empty; nothing here is ever visible to the sender.
class IgnoredScreen extends ConsumerWidget {
  const IgnoredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(ignoredItemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ignored')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ignoredItemsProvider),
        child: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text("Couldn't load. $e")),
            ],
          ),
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 80),
                    Center(child: Text('Nothing ignored')),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(8),
                  children: [for (final i in list) _IgnoredTile(item: i)],
                ),
        ),
      ),
    );
  }
}

class _IgnoredTile extends ConsumerStatefulWidget {
  const _IgnoredTile({required this.item});
  final IgnoredItem item;
  @override
  ConsumerState<_IgnoredTile> createState() => _IgnoredTileState();
}

class _IgnoredTileState extends ConsumerState<_IgnoredTile> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(ignoredItemsProvider);
      ref.invalidate(friendRequestsProvider);
      ref.invalidate(invitedWantsProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t update. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final who = item.profile?.displayName;
    final friends = ref.read(friendRepositoryProvider);
    final wants = ref.read(wantRepositoryProvider);

    final label = item.isFriendRequest
        ? 'Friend request from ${who?.isNotEmpty == true ? who : 'someone'}'
        : 'Want invite${who?.isNotEmpty == true ? ' from $who' : ''}'
              '${item.title != null ? ' · ${item.title}' : ''}';

    return Card(
      key: Key('ignored_${item.type}_${item.id}'),
      child: ListTile(
        title: Text(label),
        trailing: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                key: Key('unignore_${item.id}'),
                onPressed: () => _run(
                  () => item.isFriendRequest
                      ? friends.unignore(item.id)
                      : wants.unignore(item.id),
                ),
                child: const Text('Un-ignore'),
              ),
      ),
    );
  }
}
