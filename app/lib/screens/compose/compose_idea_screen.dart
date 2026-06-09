import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_exception.dart';
import '../../models/topic.dart';
import '../../providers/active_context.dart';
import '../../providers/providers.dart';

/// Compose a new idea (specs/api/ideas-activities.md). Friends/all_friends audience
/// this stage: pick an activity type, optionally allow suggestions and seed a couple
/// of time/location options, then POST /v1/ideas.
class ComposeIdeaScreen extends ConsumerStatefulWidget {
  const ComposeIdeaScreen({super.key});

  @override
  ConsumerState<ComposeIdeaScreen> createState() => _ComposeIdeaScreenState();
}

class _ComposeIdeaScreenState extends ConsumerState<ComposeIdeaScreen> {
  String? _topicId;
  bool _allowSuggestions = false;
  final _time = TextEditingController();
  final _location = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _time.dispose();
    _location.dispose();
    super.dispose();
  }

  List<String> _split(String raw) =>
      raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Future<void> _submit() async {
    if (_topicId == null) {
      setState(() => _error = 'Pick an activity type');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ctx = ref.read(activeContextProvider);
    try {
      await ref
          .read(activityRepositoryProvider)
          .createIdea(
            activityTypeId: _topicId!,
            allowSuggestions: _allowSuggestions,
            timeOptions: _split(_time.text),
            locationOptions: _split(_location.text),
            squadId: switch (ctx) {
              SquadContext(:final id) => id,
              FriendsContext() => null,
            },
          );
      switch (ctx) {
        case FriendsContext():
          ref.invalidate(friendsTimelineProvider);
        case SquadContext(:final id):
          ref.invalidate(squadTimelineProvider(id));
      }
      if (mounted) context.pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Couldn\'t create your idea. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(topicsProvider);
    final ctx = ref.watch(activeContextProvider);
    // Audience clarity at the moment of action (context-selector principle).
    final destination = switch (ctx) {
      FriendsContext() => 'Visible to all your friends',
      SquadContext(:final name) => 'Visible to $name members',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('New idea')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const Key('composeDestination'),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(destination)),
                ],
              ),
            ),
            topics.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Couldn\'t load activity types.\n$e'),
              data: (list) => DropdownButtonFormField<String>(
                key: const Key('topicDropdown'),
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
            const SizedBox(height: 16),
            TextField(
              key: const Key('timeOptionsField'),
              controller: _time,
              decoration: const InputDecoration(
                labelText: 'Time options (comma-separated)',
                hintText: 'Sat 7am, Sun 8am',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('locationOptionsField'),
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location options (comma-separated)',
                hintText: 'River, Lake',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('allowSuggestionsSwitch'),
              title: const Text('Let friends suggest options'),
              value: _allowSuggestions,
              onChanged: (v) => setState(() => _allowSuggestions = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('createIdeaButton'),
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Creating…' : 'Share idea'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                key: const Key('composeError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
