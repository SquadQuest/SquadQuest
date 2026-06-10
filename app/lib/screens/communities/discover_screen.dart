import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/active_context.dart';
import '../../providers/providers.dart';

/// Discover communities — search + follow (specs/screens/communities.md,
/// context-selector). Communities are found, not added; following is frictionless.
class DiscoverCommunitiesScreen extends ConsumerStatefulWidget {
  const DiscoverCommunitiesScreen({super.key});

  @override
  ConsumerState<DiscoverCommunitiesScreen> createState() => _DiscoverState();
}

class _DiscoverState extends ConsumerState<DiscoverCommunitiesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final communities = ref.watch(communitiesProvider(_search));

    return Scaffold(
      appBar: AppBar(title: const Text('Discover communities')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newCommunityFab'),
        onPressed: () => context.push('/communities/new'),
        icon: const Icon(Icons.add),
        label: const Text('New community'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('communitySearchField'),
              decoration: const InputDecoration(
                hintText: 'Search communities…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          Expanded(
            child: communities.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Couldn\'t load.\n$e')),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('No communities found.'))
                  : ListView(
                      key: const Key('discoverList'),
                      children: [
                        for (final c in list)
                          ListTile(
                            key: Key('discover_${c.id}'),
                            leading: Text(
                              c.icon ?? '📣',
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: Text(c.name),
                            subtitle: Text(
                              [
                                c.tagline,
                                '${c.followerCount} followers',
                              ].whereType<String>().join(' · '),
                            ),
                            onTap: () {
                              ref
                                  .read(activeContextProvider.notifier)
                                  .toCommunity(c.id, c.name);
                              context.go('/');
                            },
                            trailing: _FollowButton(
                              communityId: c.id,
                              following: c.youFollow,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({required this.communityId, required this.following});
  final String communityId;
  final bool following;

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .follow(widget.communityId, follow: !widget.following);
      ref.invalidate(communitiesProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.following
        ? OutlinedButton(
            key: Key('unfollow_${widget.communityId}'),
            onPressed: _busy ? null : _toggle,
            child: const Text('Following'),
          )
        : FilledButton(
            key: Key('follow_${widget.communityId}'),
            onPressed: _busy ? null : _toggle,
            child: const Text('Follow'),
          );
  }
}
