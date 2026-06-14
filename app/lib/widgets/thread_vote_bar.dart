import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/activity.dart';
import '../providers/auth_controller.dart';
import '../providers/providers.dart';

/// The persistent vote bar for an idea (specs/behaviors/thread-drawer.md): a section
/// between the thread header and the chat. **Collapsed** shows summary chips of the
/// leading time/place; tapping expands to the full voting detail (all options, vote
/// toggles, captain Confirm, "Suggest" when allow_suggestions). Brought-along ideas
/// (event_ref) instead show "Time & place set by the event" + the captain Confirm.
///
/// Self-contained: owns the busy/error/expanded state and the repo calls, swaps its
/// working copy of the activity on each action, and notifies [onChanged] so the host
/// (drawer or fallback detail screen) can refresh + keep timelines in sync.
class ThreadVoteBar extends ConsumerStatefulWidget {
  const ThreadVoteBar({
    super.key,
    required this.activity,
    this.onChanged,
    this.initiallyExpanded = false,
  });

  final Activity activity;
  final void Function(Activity updated)? onChanged;
  final bool initiallyExpanded;

  /// Whether this activity warrants a vote bar at all: an idea (not confirmed) that
  /// either has options, invites suggestions, or is a brought-along plan to confirm.
  static bool appliesTo(Activity a) =>
      !a.isConfirmed &&
      (a.timeOptions.isNotEmpty ||
          a.locationOptions.isNotEmpty ||
          a.allowSuggestions ||
          a.eventRef != null);

  @override
  ConsumerState<ThreadVoteBar> createState() => _ThreadVoteBarState();
}

class _ThreadVoteBarState extends ConsumerState<ThreadVoteBar> {
  late Activity _a = widget.activity;
  late bool _expanded = widget.initiallyExpanded;
  bool _busy = false;
  String? _error;

  @override
  void didUpdateWidget(ThreadVoteBar old) {
    super.didUpdateWidget(old);
    // Reseed only when the host swaps to a different activity.
    if (old.activity.id != widget.activity.id) _a = widget.activity;
  }

  bool get _isCaptain {
    final auth = ref.read(authControllerProvider);
    final me = auth is SignedIn ? auth.profile.id : null;
    return me != null && _a.captainId == me;
  }

  Future<void> _act(Future<Activity> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await action();
      ref.invalidate(friendsTimelineProvider);
      ref.invalidate(squadTimelineProvider);
      if (mounted) setState(() => _a = updated);
      widget.onChanged?.call(updated);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _suggest(String kind) async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(kind == 'time' ? 'Suggest a time' : 'Suggest a place'),
        content: TextField(
          key: const Key('suggestOptionField'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: kind == 'time' ? 'Saturday morning' : 'The trailhead',
          ),
          onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Suggest'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    await _act(
      () => ref.read(activityRepositoryProvider).addOption(_a.id, kind, label),
    );
  }

  ActivityOption? _leading(List<ActivityOption> opts) {
    if (opts.isEmpty) return null;
    return opts.reduce((a, b) => b.votes > a.votes ? b : a);
  }

  @override
  Widget build(BuildContext context) {
    final broughtAlong = _a.eventRef != null;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('threadVoteBar'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      child: broughtAlong
          ? _broughtAlong()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _collapsedHeader(),
                if (_expanded) ...[
                  const SizedBox(height: 4),
                  _expandedDetail(),
                ],
                if (_error != null) _errorText(),
              ],
            ),
    );
  }

  // Brought-along: time & place come from the community event; the captain just confirms.
  Widget _broughtAlong() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          const Icon(Icons.event, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Time & place set by the event')),
          if (_isCaptain)
            FilledButton(
              key: const Key('confirmBroughtAlong'),
              onPressed: _busy
                  ? null
                  : () => _act(
                      () => ref.read(activityRepositoryProvider).confirm(_a.id),
                    ),
              child: const Text('Confirm'),
            ),
        ],
      ),
      if (_error != null) _errorText(),
    ],
  );

  // Collapsed: leading time/place chips + an expand affordance for the full detail.
  Widget _collapsedHeader() {
    final t = _leading(_a.timeOptions);
    final l = _leading(_a.locationOptions);
    final chips = <Widget>[
      if (t != null) Chip(label: Text('🕒 ${t.label}')),
      if (l != null) Chip(label: Text('📍 ${l.label}')),
    ];
    return InkWell(
      key: const Key('voteBarToggle'),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Row(
        children: [
          Expanded(
            child: chips.isEmpty
                ? const Text('Vote on when & where')
                : Wrap(spacing: 6, runSpacing: 4, children: chips),
          ),
          Icon(_expanded ? Icons.expand_less : Icons.expand_more),
        ],
      ),
    );
  }

  Widget _expandedDetail() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_a.timeOptions.isNotEmpty || _a.allowSuggestions) ...[
        const _SectionLabel('When'),
        for (final o in _a.timeOptions) _optionTile(o, kind: 'time'),
        if (_a.allowSuggestions) _suggestButton('time'),
      ],
      if (_a.locationOptions.isNotEmpty || _a.allowSuggestions) ...[
        const _SectionLabel('Where'),
        for (final o in _a.locationOptions) _optionTile(o, kind: 'location'),
        if (_a.allowSuggestions) _suggestButton('location'),
      ],
    ],
  );

  Widget _optionTile(ActivityOption o, {required String kind}) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: IconButton(
      key: Key('vote_${o.id}'),
      icon: Icon(o.youVoted ? Icons.thumb_up : Icons.thumb_up_outlined),
      onPressed: _busy
          ? null
          : () => _act(
              () => ref
                  .read(activityRepositoryProvider)
                  .vote(_a.id, o.id, voted: !o.youVoted),
            ),
    ),
    title: Text(o.label),
    subtitle: Text('${o.votes} vote${o.votes == 1 ? '' : 's'}'),
    trailing: (_isCaptain && !_a.isConfirmed)
        ? TextButton(
            key: Key('confirm_${o.id}'),
            onPressed: _busy
                ? null
                : () => _act(
                    () => ref
                        .read(activityRepositoryProvider)
                        .confirm(
                          _a.id,
                          timeOptionId: kind == 'time' ? o.id : null,
                          locationOptionId: kind == 'location' ? o.id : null,
                        ),
                  ),
            child: const Text('Confirm'),
          )
        : null,
  );

  Widget _suggestButton(String kind) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      key: Key(kind == 'time' ? 'suggestTime' : 'suggestLocation'),
      onPressed: _busy ? null : () => _suggest(kind),
      icon: const Icon(Icons.add, size: 18),
      label: Text(kind == 'time' ? 'Suggest a time' : 'Suggest a place'),
    ),
  );

  Widget _errorText() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      _error!,
      key: const Key('voteBarError'),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 2),
    child: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
    ),
  );
}
