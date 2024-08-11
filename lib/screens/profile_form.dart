import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/common.dart';
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
  late final bool isNewProfile;

  void _submitProfile(BuildContext context) async {
    FocusScope.of(context).unfocus();

    final session = ref.read(authControllerProvider);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      submitted = true;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final profileController = ref.read(profileProvider.notifier);

      // upload photo
      final photo = ref.read(_photoProvider);

      Uri? photoUrl;
      if (photo != null) {
        try {
          photoUrl =
              await uploadPhoto(photo, session!.user.id, supabase, 'avatars',
                  transform: const TransformOptions(
                    width: 512,
                    height: 512,
                  ));
        } catch (error) {
          logger.e(error);

          setState(() {
            submitted = false;
          });

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to upload profile photo:\n\n$error'),
          ));

          return;
        }
      }

      // save profile
      final savedProfile = await profileController.patch({
        'id': session!.user.id,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': session.user.phone!,
        'photo': photoUrl?.toString(),
      });

      await ref.read(authControllerProvider.notifier).updateUserAttributes({
        'first_name': savedProfile.firstName,
        'last_name': savedProfile.lastName!,
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

    // redirect to next screen
    if (widget.redirect != null) {
      context.go(widget.redirect!);
    } else if (isNewProfile &&
        session.user.appMetadata['invite_friends'] != null &&
        session.user.appMetadata['invite_friends'].isNotEmpty) {
      context.goNamed('friends');
    } else {
      context.goNamed('home');
    }
  }

  @override
  void initState() {
    super.initState();

    final profile = ref.read(profileProvider);

    if (profile.hasValue && profile.value != null) {
      isNewProfile = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _firstNameController.text = profile.value!.firstName;
        _lastNameController.text = profile.value!.lastName!;
        ref.read(_photoProvider.notifier).state = profile.value!.photo;
      });
    } else {
      isNewProfile = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        _firstNameController.text = next.value!.firstName;
        _lastNameController.text = next.value!.lastName!;
        ref.read(_photoProvider.notifier).state = next.value!.photo;
      }
    });

    return AppScaffold(
        title: isNewProfile ? 'Set up your profile' : 'Update your profile',
        loadMask: submitted ? 'Saving profile...' : null,
        actions: [
          if (!submitted)
            TextButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              onPressed: () => _submitProfile(context),
              child: Text(isNewProfile ? 'Continue' : 'Save',
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
        ],
        bodyPadding: const EdgeInsets.all(16),
        body: SingleChildScrollView(
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (isNewProfile) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to SquadQuest!\n\nPlease set up your profile to get started:',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Your last name and photo will only ever be visible to your confirmed friends, everyone else will just see your first name when you post or respond to events',
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
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
                    autofillHints: const [AutofillHints.familyName],
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.done,
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
                      labelText: 'Profile photo',
                      valueProvider: _photoProvider),
                ],
              ),
            ),
          ),
        ));
  }
}
