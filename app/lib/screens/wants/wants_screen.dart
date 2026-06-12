import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../models/friend.dart';
import '../../models/topic.dart';
import '../../models/want.dart';
import '../../providers/providers.dart';

/// "Want to do" — the user's shared backlog (specs/screens/wants.md). Two groupings:
/// Yours (with invitee responses) and Invited (with respond/ignore). Promote spawns a
/// real idea via the want-promote endpoint (no parallel publish path).
class WantsScreen extends ConsumerWidget {
  const WantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final own = ref.watch(ownWantsProvider);
    final invited = ref.watch(invitedWantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Want to do')),
      floatingActionButton: FloatingActionButton(
        key: const Key('addWantButton'),
        tooltip: 'Add a want',
        onPressed: () => _openEditor(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownWantsProvider);
          ref.invalidate(invitedWantsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader('Yours'),
            own.when(
              loading: () => const _Loading(),
              error: (e, _) => _Err('$e'),
              data: (list) => list.isEmpty
                  ? const _Empty(
                      'Got a "we should do that sometime" with a friend? Capture it here and make it happen.',
                    )
                  : Column(
                      children: [for (final w in list) _OwnWantTile(want: w)],
                    ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Invited'),
            invited.when(
              loading: () => const _Loading(),
              error: (e, _) => _Err('$e'),
              data: (list) => list.isEmpty
                  ? const _Empty('No want invites right now.')
                  : Column(
                      children: [
                        for (final w in list) _InvitedWantTile(want: w),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tiles ────────────────────────────────────────────────────────────────

class _OwnWantTile extends ConsumerWidget {
  const _OwnWantTile({required this.want});
  final Want want;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responded = want.invitees.where((i) => i.response != null).toList();
    final subtitle = [
      if (want.location != null) want.location!,
      if (want.isOngoing) 'Ongoing',
      if (want.invitees.isNotEmpty)
        '${responded.length}/${want.invitees.length} responded',
    ].join(' · ');

    return Card(
      key: Key('want_${want.id}'),
      child: ListTile(
        title: Text(
          want.title?.isNotEmpty == true
              ? want.title!
              : (want.activityTypeLabel ?? 'Want'),
        ),
        subtitle: Text(
          [
            if (want.title?.isNotEmpty == true) want.activityTypeLabel,
            if (subtitle.isNotEmpty) subtitle,
          ].whereType<String>().join('\n'),
        ),
        isThreeLine: subtitle.isNotEmpty && want.title?.isNotEmpty == true,
        trailing: PopupMenuButton<String>(
          key: Key('wantMenu_${want.id}'),
          onSelected: (v) async {
            switch (v) {
              case 'promote':
                await _openPromote(context, ref, want);
              case 'edit':
                await _openEditor(context, ref, existing: want);
              case 'delete':
                await ref.read(wantRepositoryProvider).delete(want.id);
                ref.invalidate(ownWantsProvider);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'promote', child: Text('Promote to plan')),
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _openPromote(context, ref, want),
      ),
    );
  }
}

class _InvitedWantTile extends ConsumerWidget {
  const _InvitedWantTile({required this.want});
  final Want want;

  Future<void> _respond(WidgetRef ref, String value) async {
    await ref.read(wantRepositoryProvider).respond(want.id, value);
    ref.invalidate(invitedWantsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = want.ownerName ?? 'A friend';
    return Card(
      key: Key('invitedWant_${want.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              want.title?.isNotEmpty == true
                  ? want.title!
                  : (want.activityTypeLabel ?? 'Want'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('$from · ${want.activityTypeLabel ?? ''}'),
            const SizedBox(height: 8),
            if (want.yourResponse == null)
              Wrap(
                spacing: 8,
                children: [
                  for (final v in const ['in', 'interested', 'next_time'])
                    OutlinedButton(
                      key: Key('respond_${v}_${want.id}'),
                      onPressed: () => _respond(ref, v),
                      child: Text(_label(v)),
                    ),
                  TextButton(
                    key: Key('ignoreWant_${want.id}'),
                    onPressed: () async {
                      await ref.read(wantRepositoryProvider).ignore(want.id);
                      ref.invalidate(invitedWantsProvider);
                    },
                    child: const Text('Ignore'),
                  ),
                ],
              )
            else
              InputChip(
                key: Key('yourResponseChip_${want.id}'),
                label: Text(_label(want.yourResponse!)),
                onDeleted: () async {
                  await ref.read(wantRepositoryProvider).clearResponse(want.id);
                  ref.invalidate(invitedWantsProvider);
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _label(String v) => switch (v) {
    'in' => "I'm in",
    'interested' => 'Interested',
    'next_time' => 'Next time',
    _ => v,
  };
}

// ── Editor (add / edit) ──────────────────────────────────────────────────

Future<void> _openEditor(
  BuildContext context,
  WidgetRef ref, {
  Want? existing,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _WantEditor(existing: existing),
    ),
  );
}

class _WantEditor extends ConsumerStatefulWidget {
  const _WantEditor({this.existing});
  final Want? existing;

  @override
  ConsumerState<_WantEditor> createState() => _WantEditorState();
}

class _WantEditorState extends ConsumerState<_WantEditor> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  String? _topicId;
  String _kind = 'one_shot';
  final Set<String> _invitees = {};
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final w = widget.existing;
    _title = TextEditingController(text: w?.title ?? '');
    _location = TextEditingController(text: w?.location ?? '');
    _notes = TextEditingController(text: w?.notes ?? '');
    _topicId = w?.activityTypeId;
    _kind = w?.kind ?? 'one_shot';
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_topicId == null) {
      setState(() => _error = 'Pick an activity type');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(wantRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          activityTypeId: _topicId,
          title: _title.text.trim(),
          location: _location.text.trim(),
          notes: _notes.text.trim(),
          kind: _kind,
        );
      } else {
        await repo.create(
          activityTypeId: _topicId!,
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          location: _location.text.trim().isEmpty
              ? null
              : _location.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          kind: _kind,
          inviteeIds: _invitees.toList(),
        );
      }
      ref.invalidate(ownWantsProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't save. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(topicsProvider);
    final friends = ref.watch(friendsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        key: const Key('wantEditor'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? 'Edit want' : 'Add a want',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          topics.when(
            loading: () => const _Loading(),
            error: (e, _) => _Err('$e'),
            data: (list) => DropdownButtonFormField<String>(
              key: const Key('wantTopicDropdown'),
              initialValue: _topicId,
              decoration: const InputDecoration(
                labelText: 'Activity type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final Topic t in list)
                  DropdownMenuItem(value: t.id, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _topicId = v),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('wantTitleField'),
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              hintText: 'FDR lake paddle',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('wantLocationField'),
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('wantNotesField'),
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const Key('wantOngoingSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Ongoing'),
            subtitle: const Text(
              'A standing aspiration you can plan again and again',
            ),
            value: _kind == 'ongoing',
            onChanged: (v) =>
                setState(() => _kind = v ? 'ongoing' : 'one_shot'),
          ),
          // Invitees only on create (edit invites via the want menu later).
          if (!_isEdit) ...[
            const SizedBox(height: 8),
            Text(
              'Invite friends',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            friends.when(
              loading: () => const _Loading(),
              error: (e, _) => _Err('$e'),
              data: (list) => Wrap(
                spacing: 8,
                children: [
                  for (final Friend f in list)
                    FilterChip(
                      key: Key('inviteChip_${f.id}'),
                      label: Text(
                        f.displayName.isEmpty ? 'Friend' : f.displayName,
                      ),
                      selected: _invitees.contains(f.id),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _invitees.add(f.id);
                        } else {
                          _invitees.remove(f.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('saveWantButton'),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : (_isEdit ? 'Save' : 'Add want')),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Promote ────────────────────────────────────────────────────────────────

Future<void> _openPromote(
  BuildContext context,
  WidgetRef ref,
  Want want,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _PromoteSheet(want: want),
    ),
  );
}

class _PromoteSheet extends ConsumerStatefulWidget {
  const _PromoteSheet({required this.want});
  final Want want;

  @override
  ConsumerState<_PromoteSheet> createState() => _PromoteSheetState();
}

class _PromoteSheetState extends ConsumerState<_PromoteSheet> {
  late final TextEditingController _time;
  late final TextEditingController _location;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _time = TextEditingController();
    _location = TextEditingController(text: widget.want.location ?? '');
  }

  @override
  void dispose() {
    _time.dispose();
    _location.dispose();
    super.dispose();
  }

  List<String> _split(String raw) =>
      raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Future<void> _promote() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(wantRepositoryProvider)
          .promote(
            widget.want.id,
            timeOptions: _split(_time.text),
            locationOptions: _split(_location.text),
          );
      ref.invalidate(ownWantsProvider);
      ref.invalidate(friendsTimelineProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Posted to your friends!')),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't promote. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.want;
    final names = w.invitees.map((i) => i.name).whereType<String>().toList();
    final audience = names.isEmpty ? 'all your friends' : names.join(', ');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        key: const Key('promoteSheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Promote to a plan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text('${w.activityTypeLabel ?? 'Activity'} · with $audience'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('promoteTimeField'),
            controller: _time,
            decoration: const InputDecoration(
              labelText: 'Time options (comma-separated)',
              hintText: 'Sat 7am, Sun 8am',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('promoteLocationField'),
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'Location options (comma-separated)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('confirmPromoteButton'),
            onPressed: _busy ? null : _promote,
            child: Text(_busy ? 'Posting…' : 'Post it'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Small shared bits ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: TextStyle(color: Theme.of(context).hintColor)),
  );
}

class _Err extends StatelessWidget {
  const _Err(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text("Couldn't load. $text"),
  );
}
