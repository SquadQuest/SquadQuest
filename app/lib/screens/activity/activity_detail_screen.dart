import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../models/activity.dart';
import '../../providers/auth_controller.dart';
import '../../providers/providers.dart';
import '../../widgets/thread_view.dart';

/// Activity detail (specs/api/ideas-activities.md + response-system). Seeded from
/// the [Activity] passed by the timeline; every action returns the updated activity,
/// which replaces local state and invalidates the timeline so the list stays in sync.
class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({super.key, required this.activity});

  /// May be null on a cold deep-link (no GET /v1/ideas/:id this stage).
  final Activity? activity;

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  late Activity? _activity = widget.activity;
  bool _busy = false;
  String? _error;

  bool get _isCaptain {
    final auth = ref.read(authControllerProvider);
    final me = auth is SignedIn ? auth.profile.id : null;
    return me != null && _activity?.captainId == me;
  }

  Future<void> _act(Future<Activity> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await action();
      // Refresh whichever timeline this item lives on (friends or any squad).
      ref.invalidate(friendsTimelineProvider);
      ref.invalidate(squadTimelineProvider);
      if (mounted) setState(() => _activity = updated);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _activity;
    return Scaffold(
      appBar: AppBar(title: Text(a?.activityTypeLabel ?? 'Activity')),
      body: a == null
          ? const Center(
              key: Key('detailUnavailable'),
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Open this from your timeline.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              key: const Key('activityDetail'),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${a.captainName ?? 'Someone'} · ${a.activityTypeLabel ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  a.isConfirmed
                      ? 'Confirmed · ${[a.confirmedTime, a.confirmedLocation].whereType<String>().join(' · ')}'
                      : 'Idea · ${a.audienceSummary ?? ''}',
                ),
                const Divider(height: 32),

                // Your response
                Text(
                  'Your response',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _ResponseSelector(
                  value: a.yourResponse,
                  busy: _busy,
                  onSelect: (v) => _act(
                    () => v == null
                        ? ref
                              .read(activityRepositoryProvider)
                              .clearResponse(a.id)
                        : ref
                              .read(activityRepositoryProvider)
                              .setResponse(a.id, v),
                  ),
                ),
                Text(
                  '${a.inCount} in · ${a.interestedCount} interested',
                  key: const Key('responseCounts'),
                ),

                if (a.timeOptions.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text('When', style: Theme.of(context).textTheme.titleMedium),
                  for (final o in a.timeOptions)
                    _OptionTile(
                      option: o,
                      busy: _busy,
                      onVote: (voted) => _act(
                        () => ref
                            .read(activityRepositoryProvider)
                            .vote(a.id, o.id, voted: voted),
                      ),
                      onConfirm: _isCaptain && !a.isConfirmed
                          ? () => _act(
                              () => ref
                                  .read(activityRepositoryProvider)
                                  .confirm(a.id, timeOptionId: o.id),
                            )
                          : null,
                    ),
                ],

                if (a.locationOptions.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text('Where', style: Theme.of(context).textTheme.titleMedium),
                  for (final o in a.locationOptions)
                    _OptionTile(
                      option: o,
                      busy: _busy,
                      onVote: (voted) => _act(
                        () => ref
                            .read(activityRepositoryProvider)
                            .vote(a.id, o.id, voted: voted),
                      ),
                      onConfirm: _isCaptain && !a.isConfirmed
                          ? () => _act(
                              () => ref
                                  .read(activityRepositoryProvider)
                                  .confirm(a.id, locationOptionId: o.id),
                            )
                          : null,
                    ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    key: const Key('detailError'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],

                const Divider(height: 32),
                Text(
                  'Discussion',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ThreadView(targetType: 'activity', targetId: a.id),
              ],
            ),
    );
  }
}

class _ResponseSelector extends StatelessWidget {
  const _ResponseSelector({
    required this.value,
    required this.busy,
    required this.onSelect,
  });

  final String? value;
  final bool busy;
  final void Function(String? value) onSelect;

  @override
  Widget build(BuildContext context) {
    const labels = {
      'in': "I'm in",
      'interested': 'Interested',
      'next_time': 'Next time',
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in labels.entries)
          ChoiceChip(
            key: Key('response_${entry.key}'),
            label: Text(entry.value),
            selected: value == entry.key,
            onSelected: busy ? null : (sel) => onSelect(sel ? entry.key : null),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.busy,
    required this.onVote,
    this.onConfirm,
  });

  final ActivityOption option;
  final bool busy;
  final void Function(bool voted) onVote;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        key: Key('vote_${option.id}'),
        icon: Icon(option.youVoted ? Icons.thumb_up : Icons.thumb_up_outlined),
        onPressed: busy ? null : () => onVote(!option.youVoted),
      ),
      title: Text(option.label),
      subtitle: Text('${option.votes} vote${option.votes == 1 ? '' : 's'}'),
      trailing: onConfirm == null
          ? null
          : TextButton(
              key: Key('confirm_${option.id}'),
              onPressed: busy ? null : onConfirm,
              child: const Text('Confirm'),
            ),
    );
  }
}
