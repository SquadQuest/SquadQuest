import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_controller.dart';
import '../../widgets/photo_picker.dart';

/// The signed-in user's own profile: view/edit name + photo, see phone (read-only),
/// and sign out. The post-onboarding home for the identity the welcome step first
/// set. See specs/screens/profile.md. Reachable from the timeline app-bar avatar.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  String? _photoUrl; // current/pending photo URL
  bool _busy = false;
  String? _error;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(authControllerProvider.notifier).currentProfile;
    _firstName = TextEditingController(text: p?.firstName ?? '')
      ..addListener(_markDirty);
    _lastName = TextEditingController(text: p?.lastName ?? '')
      ..addListener(_markDirty);
    _photoUrl = p?.photo;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  bool get _canSave => _dirty && _firstName.text.trim().isNotEmpty && !_busy;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final last = _lastName.text.trim();
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            firstName: _firstName.text.trim(),
            lastName: last.isEmpty ? null : last,
            photo: _photoUrl,
          );
      if (mounted) {
        setState(() {
          _busy = false;
          _dirty = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved')));
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
    final profile = ref.watch(authControllerProvider.notifier).currentProfile;
    final phone = profile?.phone;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                key: const Key('profileForm'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: PhotoPicker(
                      kind: 'profile',
                      currentUrl: _photoUrl,
                      fallbackIcon: Icons.person,
                      onUploaded: (url) => setState(() {
                        _photoUrl = url;
                        _dirty = true;
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to change your photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('firstNameField'),
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('lastNameField'),
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      labelText: 'Last name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Phone is the identity key — shown, not editable here.
                  if (phone != null)
                    TextField(
                      key: const Key('phoneField'),
                      enabled: false,
                      controller: TextEditingController(text: phone),
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('saveProfileButton'),
                    onPressed: _canSave ? _save : null,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  ListTile(
                    key: const Key('wantsLink'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.checklist_outlined),
                    title: const Text('Want to do'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/wants'),
                  ),
                  ListTile(
                    key: const Key('ignoredLink'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.visibility_off_outlined),
                    title: const Text('Ignored'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/ignored'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const Key('signOutButton'),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                    onPressed: _busy
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .logout(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
