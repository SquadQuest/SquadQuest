import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/community.dart';
import '../../providers/active_context.dart';
import '../../providers/providers.dart';

/// Create or edit a community (leader tooling — specs/screens/communities.md).
/// Create: the caller becomes leader and the new community becomes the active
/// context. Edit (when [existing] is set): PATCHes and pops back.
class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key, this.existing});

  final Community? existing;

  @override
  ConsumerState<CreateCommunityScreen> createState() =>
      _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  late final TextEditingController _name;
  late final TextEditingController _tagline;
  late final TextEditingController _icon;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _tagline = TextEditingController(text: e?.tagline ?? '');
    _icon = TextEditingController(text: e?.icon ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
    _icon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(communityRepositoryProvider);
    final tagline = _tagline.text.trim();
    final icon = _icon.text.trim();
    try {
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          name: name,
          tagline: tagline.isEmpty ? null : tagline,
          icon: icon.isEmpty ? null : icon,
        );
        ref.invalidate(communitiesProvider);
        if (mounted) context.pop();
      } else {
        final created = await repo.create(
          name: name,
          tagline: tagline.isEmpty ? null : tagline,
          icon: icon.isEmpty ? null : icon,
        );
        ref.invalidate(communitiesProvider);
        if (mounted) {
          ref
              .read(activeContextProvider.notifier)
              .toCommunity(created.id, created.name);
          context.go('/');
        }
      }
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
      appBar: AppBar(title: Text(_isEdit ? 'Edit community' : 'New community')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            key: const Key('communityForm'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('communityNameField'),
                controller: _name,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('communityTaglineField'),
                controller: _tagline,
                decoration: const InputDecoration(
                  labelText: 'Tagline (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('communityIconField'),
                controller: _icon,
                decoration: const InputDecoration(
                  labelText: 'Icon emoji (optional)',
                  hintText: '🚲',
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
                key: const Key('communitySave'),
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Save' : 'Create community'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
