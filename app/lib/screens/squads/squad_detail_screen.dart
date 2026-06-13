import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../models/friend.dart';
import '../../models/squad.dart';
import '../../providers/auth_controller.dart';
import '../../providers/providers.dart';

/// Squad members (specs/screens/squads.md). Shows the roster; the captain can add
/// accepted friends who aren't already members. Removing/leaving is still deferred.
class SquadDetailScreen extends ConsumerWidget {
  const SquadDetailScreen({super.key, required this.squadId});

  final String squadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(squadDetailProvider(squadId));
    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.name ?? 'Squad')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              "Couldn't load this squad.\n$e",
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (squad) {
          final myId = ref
              .read(authControllerProvider.notifier)
              .currentProfile
              ?.id;
          final isCaptain = squad.members.any(
            (m) => m.role == 'captain' && m.id == myId,
          );
          return ListView(
            key: const Key('squadMembersList'),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'MEMBERS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              for (final m in squad.members)
                ListTile(
                  key: Key('squadMember_${m.id}'),
                  leading: CircleAvatar(
                    foregroundImage: (m.photo != null && m.photo!.isNotEmpty)
                        ? NetworkImage(m.photo!)
                        : null,
                    child: Text((m.firstName ?? '?').characters.first),
                  ),
                  title: Text(m.firstName ?? 'Member'),
                  trailing: m.role == 'captain'
                      ? const Chip(label: Text('Captain'))
                      : null,
                ),
              if (isCaptain) ...[
                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton.icon(
                    key: const Key('addMembersButton'),
                    onPressed: () => _openAddMembers(context, ref, squad),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Add members'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openAddMembers(BuildContext context, WidgetRef ref, SquadDetail squad) {
    final memberIds = squad.members.map((m) => m.id).toSet();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _AddMembersSheet(squadId: squadId, memberIds: memberIds),
    );
  }
}

/// Friend picker limited to accepted friends not already in the squad. Each tap
/// adds one member (the backend is friend-gated + idempotent).
class _AddMembersSheet extends ConsumerStatefulWidget {
  const _AddMembersSheet({required this.squadId, required this.memberIds});
  final String squadId;
  final Set<String> memberIds;

  @override
  ConsumerState<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends ConsumerState<_AddMembersSheet> {
  final _adding = <String>{};
  String? _error;

  Future<void> _add(Friend friend) async {
    setState(() {
      _adding.add(friend.id);
      _error = null;
    });
    try {
      await ref
          .read(squadRepositoryProvider)
          .addMember(widget.squadId, friend.id);
      ref.invalidate(squadDetailProvider(widget.squadId));
      ref.invalidate(squadsProvider);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't add. Please try again.");
    } finally {
      if (mounted) setState(() => _adding.remove(friend.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: friends.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              "Couldn't load friends.\n$e",
              textAlign: TextAlign.center,
            ),
          ),
          data: (list) {
            final candidates = list
                .where((f) => !widget.memberIds.contains(f.id))
                .toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add members',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      _error!,
                      key: const Key('addMemberError'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'All your friends are already in this squad.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      key: const Key('addMemberPicker'),
                      shrinkWrap: true,
                      children: [
                        for (final f in candidates)
                          ListTile(
                            key: Key('addFriend_${f.id}'),
                            leading: CircleAvatar(
                              foregroundImage:
                                  (f.photo != null && f.photo!.isNotEmpty)
                                  ? NetworkImage(f.photo!)
                                  : null,
                              child: Text(
                                (f.firstName ?? '?').characters.first,
                              ),
                            ),
                            title: Text(
                              f.displayName.isEmpty ? 'Friend' : f.displayName,
                            ),
                            trailing: _adding.contains(f.id)
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add),
                            onTap: _adding.contains(f.id)
                                ? null
                                : () => _add(f),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
