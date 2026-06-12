import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/friend.dart';
import '../../providers/providers.dart';

/// The People screen: the accepted friend graph, pending connection requests
/// (incoming accept/decline + outgoing), and add-by-phone. Double opt-in — see
/// specs/behaviors/friend-connections.md + specs/api/friends.md.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    final requests = ref.watch(friendRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(friendsProvider);
          ref.invalidate(friendRequestsProvider);
          await Future.wait([
            ref.read(friendsProvider.future),
            ref.read(friendRequestsProvider.future),
          ]);
        },
        child: ListView(
          key: const Key('friendsList'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _AddByPhone(),
            const Divider(height: 1),

            // Incoming requests — actionable first.
            ...requests.maybeWhen(
              data: (r) => r.incoming.isEmpty
                  ? const <Widget>[]
                  : [
                      const _SectionHeader('REQUESTS'),
                      for (final req in r.incoming) _IncomingTile(req),
                    ],
              orElse: () => const <Widget>[],
            ),

            // Accepted friends.
            const _SectionHeader('FRIENDS'),
            friends.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('Couldn\'t load friends.\n$e')),
              ),
              data: (list) => list.isEmpty
                  ? const Padding(
                      key: Key('friendsEmpty'),
                      padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Text(
                        'No friends yet. Add someone by phone number above.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(children: [for (final f in list) _FriendTile(f)]),
            ),

            // Outgoing (pending) requests.
            ...requests.maybeWhen(
              data: (r) => r.outgoing.isEmpty
                  ? const <Widget>[]
                  : [
                      const _SectionHeader('PENDING'),
                      for (final req in r.outgoing) _OutgoingTile(req),
                    ],
              orElse: () => const <Widget>[],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

CircleAvatar _avatar(BuildContext context, String? name, {Color? color}) =>
    CircleAvatar(
      backgroundColor: color,
      child: Text((name == null || name.isEmpty ? '?' : name).characters.first),
    );

class _FriendTile extends StatelessWidget {
  const _FriendTile(this.friend);
  final Friend friend;
  @override
  Widget build(BuildContext context) {
    final name = friend.displayName;
    return ListTile(
      key: Key('friend_${friend.id}'),
      leading: _avatar(context, name.isEmpty ? null : name),
      title: Text(name.isEmpty ? 'Friend' : name),
      subtitle: friend.onV2
          ? null
          : const Text('Not on SquadQuest yet · invited'),
    );
  }
}

class _IncomingTile extends ConsumerStatefulWidget {
  const _IncomingTile(this.request);
  final FriendRequest request;
  @override
  ConsumerState<_IncomingTile> createState() => _IncomingTileState();
}

class _IncomingTileState extends ConsumerState<_IncomingTile> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(friendRepositoryProvider).accept(widget.request.id);
      ref.invalidate(friendRequestsProvider);
      ref.invalidate(friendsProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t respond. Try again.')),
        );
      }
    }
  }

  Future<void> _ignore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(friendRepositoryProvider).ignore(widget.request.id);
      ref.invalidate(friendRequestsProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t ignore. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.request.profile.displayName;
    return ListTile(
      key: Key('incoming_${widget.request.id}'),
      leading: _avatar(
        context,
        name.isEmpty ? null : name,
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      title: Text(name.isEmpty ? 'Someone' : name),
      subtitle: const Text('wants to connect'),
      trailing: _busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('ignore_${widget.request.id}'),
                  icon: const Icon(Icons.close),
                  tooltip: 'Ignore',
                  onPressed: _ignore,
                ),
                IconButton(
                  key: Key('accept_${widget.request.id}'),
                  icon: const Icon(Icons.check),
                  tooltip: 'Accept',
                  onPressed: _accept,
                ),
              ],
            ),
    );
  }
}

class _OutgoingTile extends StatelessWidget {
  const _OutgoingTile(this.request);
  final FriendRequest request;
  @override
  Widget build(BuildContext context) {
    final name = request.profile.displayName;
    return ListTile(
      key: Key('outgoing_${request.id}'),
      leading: _avatar(context, name.isEmpty ? null : name),
      title: Text(name.isEmpty ? 'Invited' : name),
      subtitle: const Text('Request sent'),
      trailing: const Icon(Icons.schedule),
    );
  }
}

class _AddByPhone extends ConsumerStatefulWidget {
  const _AddByPhone();
  @override
  ConsumerState<_AddByPhone> createState() => _AddByPhoneState();
}

class _AddByPhoneState extends ConsumerState<_AddByPhone> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = _controller.text.trim();
    if (phone.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final status = await ref
          .read(friendRepositoryProvider)
          .sendRequest(phone);
      _controller.clear();
      ref.invalidate(friendRequestsProvider);
      if (status == 'accepted') ref.invalidate(friendsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted' ? 'Connected!' : 'Request sent.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t send. Check the number.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('addFriendPhoneField'),
              controller: _controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                labelText: 'Add a friend by phone',
                hintText: '+1 555 555 1000',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            key: const Key('addFriendSend'),
            icon: const Icon(Icons.person_add),
            tooltip: 'Send request',
            onPressed: _busy ? null : _send,
          ),
        ],
      ),
    );
  }
}
