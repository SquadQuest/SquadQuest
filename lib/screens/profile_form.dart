import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/components/pickers/photo.dart';

class ProfileFormScreen extends ConsumerStatefulWidget {
  final String? redirect;

  const ProfileFormScreen({super.key, this.redirect});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _photoProvider = StateProvider<Uri?>((ref) => null);

  bool submitted = false;

  void _submitProfile(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      submitted = true;
    });

    try {
      final session = ref.read(authControllerProvider);
      final supabase = ref.read(supabaseClientProvider);
      final profileController = ref.read(profileProvider.notifier);

      // upload photo
      final photo = ref.read(_photoProvider);

      String? photoUrl;
      if (photo != null) {
        if (photo.isScheme('blob') || photo.isScheme('file')) {
          if (photo.isScheme('file')) {
            await supabase.storage.from('avatars').upload(
                session!.user.id, File(photo.toFilePath()),
                fileOptions: const FileOptions(upsert: true));
          } else {
            final response = await http.get(photo);
            await supabase.storage.from('avatars').uploadBinary(
                session!.user.id, response.bodyBytes,
                fileOptions: FileOptions(
                    upsert: true,
                    contentType: response.headers['content-type']));
          }
          photoUrl = supabase.storage.from('avatars').getPublicUrl(
                session.user.id,
                transform: const TransformOptions(
                  width: 512,
                  height: 512,
                ),
              );
          // append cache buster to force refresh
          photoUrl = '$photoUrl&v=${DateTime.now().millisecondsSinceEpoch}';
        } else {
          photoUrl = photo.toString();
        }
      }

      // save profile
      final savedProfile = await profileController.patch({
        'id': session!.user.id,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': session.user.phone!,
        'photo': photoUrl,
      });

      await ref.read(authControllerProvider.notifier).updateUserAttributes({
        'first_name': savedProfile.firstName,
        'last_name': savedProfile.lastName,
        'profile_initialized': true,
      });
    } catch (error) {
      setState(() {
        submitted = false;
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update profile:\n\n$error'),
      ));

      return;
    }

    if (!context.mounted) return;

    context.go(widget.redirect ?? '/');
  }

  @override
  void initState() {
    super.initState();

    final profile = ref.read(profileProvider);

    if (profile.hasValue && profile.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _firstNameController.text = profile.value!.firstName;
        _lastNameController.text = profile.value!.lastName;
        ref.read(_photoProvider.notifier).state = profile.value!.photo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;

    ref.listen(profileProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        _firstNameController.text = next.value!.firstName;
        _lastNameController.text = next.value!.lastName;
        ref.read(_photoProvider.notifier).state = next.value!.photo;
      }
    });

    return AppScaffold(
      title: profile != null ? 'Update your profile' : 'Set up your profile',
      showDrawer: profile != null,
      bodyPadding: const EdgeInsets.only(bottom: 16),
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (profile == null)
                const Text(
                  'Welcome to SquadQuest!\n\nPlease set up your profile to get started:',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              TextFormField(
                readOnly: submitted,
                autofillHints: const [AutofillHints.givenName],
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person),
                  labelText: 'First name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
                controller: _firstNameController,
              ),
              TextFormField(
                readOnly: submitted,
                autofillHints: const [AutofillHints.familyName],
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person),
                  labelText: 'Last name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
                controller: _lastNameController,
              ),
              const SizedBox(height: 32),
              FormPhotoPicker(
                  labelText: 'Profile photo', valueProvider: _photoProvider),
              const SizedBox(height: 32),
              submitted
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed:
                          submitted ? null : () => _submitProfile(context),
                      child: const Text(
                        'Save profile',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
              if (profile != null) ...[
                const Spacer(),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      launchUrl(Uri.parse(
                          'https://squadquest.app/request-deletion.html'));
                    },
                    child: const Text('Delete my account',
                        style: TextStyle(color: Colors.white)))
              ]
            ],
          ),
        ),
      ),
    );
  }
}
