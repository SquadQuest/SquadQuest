import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/community.dart';
import '../../providers/providers.dart';

/// Post or edit a community event (leader tooling — specs/screens/communities.md).
/// time / recurrence / location are free-text display strings (see data-model).
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({
    super.key,
    required this.communityId,
    this.existing,
  });

  final String communityId;
  final CommunityEvent? existing;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  late final TextEditingController _title;
  late final TextEditingController _time;
  late final TextEditingController _recurrence;
  late final TextEditingController _location;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _time = TextEditingController(text: e?.time ?? '');
    _recurrence = TextEditingController(text: e?.recurrence ?? '');
    _location = TextEditingController(text: e?.location ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _time.dispose();
    _recurrence.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _busy) {
      setState(() => _error = 'Please enter a title.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(communityRepositoryProvider);
    String? orNull(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      if (_isEdit) {
        await repo.updateEvent(
          widget.existing!.id,
          title: title,
          time: orNull(_time),
          recurrence: orNull(_recurrence),
          location: orNull(_location),
        );
      } else {
        await repo.createEvent(
          widget.communityId,
          title: title,
          time: orNull(_time),
          recurrence: orNull(_recurrence),
          location: orNull(_location),
        );
      }
      ref.invalidate(communityEventsProvider(widget.communityId));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Couldn\'t save. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit event' : 'Post event')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            key: const Key('eventForm'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('eventTitleField'),
                controller: _title,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('eventTimeField'),
                controller: _time,
                decoration: const InputDecoration(
                  labelText: 'When (optional)',
                  hintText: 'Wed · 6:30pm',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('eventRecurrenceField'),
                controller: _recurrence,
                decoration: const InputDecoration(
                  labelText: 'Recurrence (optional)',
                  hintText: 'Every Wed',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('eventLocationField'),
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  hintText: 'Clark Park → Kelly Drive',
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
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('eventSave'),
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Save' : 'Post event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
