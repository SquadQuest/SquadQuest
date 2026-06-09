import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_exception.dart';
import '../../providers/active_context.dart';
import '../../providers/providers.dart';

/// Create a squad: name + pick members from your friends (specs/screens/squads.md).
/// On success the new squad becomes the active context. Fuller membership
/// management is deferred.
class CreateSquadScreen extends ConsumerStatefulWidget {
  const CreateSquadScreen({super.key});

  @override
  ConsumerState<CreateSquadScreen> createState() => _CreateSquadScreenState();
}

class _CreateSquadScreenState extends ConsumerState<CreateSquadScreen> {
  final _name = TextEditingController();
  final _selected = <String>{};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give your squad a name');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final squad = await ref
          .read(squadRepositoryProvider)
          .create(_name.text.trim(), _selected.toList());
      ref.invalidate(squadsProvider);
      ref.read(activeContextProvider.notifier).toSquad(squad.id, squad.name);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Couldn\'t create the squad. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New squad')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('squadNameField'),
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Squad name',
                hintText: 'Wednesday Riders',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add members',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: friends.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Couldn\'t load friends.\n$e')),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No friends yet — you can create the squad solo and add members later.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      key: const Key('friendPicker'),
                      children: [
                        for (final f in list)
                          CheckboxListTile(
                            key: Key('friend_${f.id}'),
                            value: _selected.contains(f.id),
                            title: Text(
                              [
                                    f.firstName,
                                    f.lastName,
                                  ].whereType<String>().join(' ').trim().isEmpty
                                  ? 'Friend'
                                  : [
                                      f.firstName,
                                      f.lastName,
                                    ].whereType<String>().join(' ').trim(),
                            ),
                            onChanged: (sel) => setState(() {
                              if (sel ?? false) {
                                _selected.add(f.id);
                              } else {
                                _selected.remove(f.id);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                key: const Key('createSquadError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const Key('createSquadButton'),
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Creating…' : 'Create squad'),
            ),
          ),
        ],
      ),
    );
  }
}
