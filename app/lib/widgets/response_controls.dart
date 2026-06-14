import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/activity.dart';
import '../providers/providers.dart';

/// The three-value response control (specs/behaviors/response-system.md): "I'm in" /
/// "Interested" / "Next time" — no decline. **Inline + collapsing:** unresponded shows
/// all three buttons; after responding it collapses to a single chip showing the choice,
/// and tapping that chip re-expands to change or clear it.
///
/// Self-contained: owns its busy + collapsed state and the repo call, seeds from the
/// activity's `your_response`, and notifies [onChanged] with the updated activity so the
/// host can keep its own copy + the timelines in sync.
class ResponseControls extends ConsumerStatefulWidget {
  const ResponseControls({
    super.key,
    required this.activity,
    this.onChanged,
    this.dense = false,
  });

  final Activity activity;
  final void Function(Activity updated)? onChanged;

  /// Tighter layout for timeline tiles (vs. the roomier thread header).
  final bool dense;

  @override
  ConsumerState<ResponseControls> createState() => _ResponseControlsState();
}

class _ResponseControlsState extends ConsumerState<ResponseControls> {
  static const _labels = {
    'in': "I'm in",
    'interested': 'Interested',
    'next_time': 'Next time',
  };

  late String? _response = widget.activity.yourResponse;
  // Collapsed once you've responded; expand on demand to change.
  late bool _expanded = widget.activity.yourResponse == null;
  bool _busy = false;

  @override
  void didUpdateWidget(ResponseControls old) {
    super.didUpdateWidget(old);
    if (old.activity.id != widget.activity.id) {
      _response = widget.activity.yourResponse;
      _expanded = widget.activity.yourResponse == null;
    }
  }

  Future<void> _set(String? value) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(activityRepositoryProvider);
      final updated = value == null
          ? await repo.clearResponse(widget.activity.id)
          : await repo.setResponse(widget.activity.id, value);
      ref.invalidate(friendsTimelineProvider);
      ref.invalidate(squadTimelineProvider);
      if (mounted) {
        setState(() {
          _response = updated.yourResponse;
          _expanded = updated.yourResponse == null; // collapse after choosing
        });
      }
      widget.onChanged?.call(updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t save your response.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Collapsed: a single chip showing the choice; tap to re-expand.
    if (!_expanded && _response != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          key: const Key('responseChip'),
          avatar: const Icon(Icons.check, size: 18),
          label: Text(_labels[_response] ?? _response!),
          onPressed: _busy ? null : () => setState(() => _expanded = true),
        ),
      );
    }

    // Expanded: all three options (+ a clear affordance once a response exists).
    return Wrap(
      spacing: widget.dense ? 4 : 8,
      children: [
        for (final e in _labels.entries)
          ChoiceChip(
            key: Key('response_${e.key}'),
            label: Text(e.value),
            selected: _response == e.key,
            onSelected: _busy ? null : (sel) => _set(sel ? e.key : null),
          ),
      ],
    );
  }
}
