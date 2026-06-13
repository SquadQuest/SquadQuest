import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/topic.dart';
import '../providers/providers.dart';

/// The chosen activity type: either an existing [topic], or a new free-text
/// [label] to create on the fly (server find-or-creates). See specs/api/topics.md.
class TopicSelection {
  const TopicSelection.existing(this.topic) : label = null;
  const TopicSelection.newLabel(this.label) : topic = null;

  final Topic? topic;
  final String? label;

  bool get isEmpty => topic == null && (label == null || label!.trim().isEmpty);
  String get display => topic?.label ?? label ?? '';
}

/// A tappable activity-type field: opens a searchable picker (official types first)
/// that also lets the user create a new community type on the fly. Reused by the
/// idea composer and the want editor.
class TopicPicker extends ConsumerWidget {
  const TopicPicker({
    super.key,
    required this.selection,
    required this.onChanged,
  });

  final TopicSelection? selection;
  final ValueChanged<TopicSelection> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      key: const Key('topicPicker'),
      onTap: () async {
        final result = await showModalBottomSheet<TopicSelection>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _TopicPickerSheet(),
        );
        if (result != null) onChanged(result);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Activity type',
          border: OutlineInputBorder(),
        ),
        child: Text(
          selection?.isEmpty == false
              ? selection!.display
              : 'Choose or create…',
          style: selection?.isEmpty == false
              ? null
              : TextStyle(color: Theme.of(context).hintColor),
        ),
      ),
    );
  }
}

class _TopicPickerSheet extends ConsumerStatefulWidget {
  const _TopicPickerSheet();
  @override
  ConsumerState<_TopicPickerSheet> createState() => _TopicPickerSheetState();
}

class _TopicPickerSheetState extends ConsumerState<_TopicPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(topicsProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                key: const Key('topicSearchField'),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search or type a new activity…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: topics.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text("Couldn't load types.\n$e")),
                data: (all) {
                  final q = _query.trim().toLowerCase();
                  final matches = q.isEmpty
                      ? all
                      : all
                            .where((t) => t.label.toLowerCase().contains(q))
                            .toList();
                  // Offer "create" when the typed text isn't an exact (case-insensitive)
                  // label match — the server still dedups on normalized match.
                  final exact =
                      q.isNotEmpty &&
                      all.any((t) => t.label.toLowerCase() == q);
                  return ListView(
                    children: [
                      if (q.isNotEmpty && !exact)
                        ListTile(
                          key: const Key('createTopicOption'),
                          leading: const Icon(Icons.add),
                          title: Text('Create "${_query.trim()}"'),
                          subtitle: const Text('New activity type'),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(TopicSelection.newLabel(_query.trim())),
                        ),
                      for (final t in matches)
                        ListTile(
                          key: Key('topicOption_${t.id}'),
                          title: Text(t.label),
                          trailing: t.isOfficial
                              ? null
                              : const Chip(
                                  label: Text('community'),
                                  visualDensity: VisualDensity.compact,
                                ),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(TopicSelection.existing(t)),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
