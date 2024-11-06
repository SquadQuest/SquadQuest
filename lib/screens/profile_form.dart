import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/router.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/components/pickers/photo.dart';
import 'package:squadquest/models/user.dart';

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
  late Color _selectedColor;
  String? _initialTrailColor;

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

      // Convert color to hex string
      final colorString =
          '#${_selectedColor.value.toRadixString(16).padRight(8, '0').substring(2)}';

      // save profile
      final savedProfile = await profileController.patch({
        'id': session!.user.id,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': session.user.phone!,
        'photo': photoUrl?.toString(),
        'trail_color': colorString,
      });

      await ref.read(authControllerProvider.notifier).updateUserAttributes({
        'first_name': savedProfile.firstName,
        'last_name': savedProfile.lastName!,
        'profile_initialized': true,
      });

      // refresh network if profile just got created
      if (isNewProfile) {
        // small manual delay to allow async backend trigger to initialize friends
        await Future.delayed(const Duration(seconds: 1));
        await ref.read(profilesCacheProvider.notifier).loadNetwork();
      }
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

    // redirect to next screen
    goInitialLocation(widget.redirect);
  }

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick your trail color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _selectedColor,
              onColorChanged: (Color color) {
                setState(() {
                  _selectedColor = color;
                });
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Done'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    final profile = ref.read(profileProvider);
    final session = ref.read(authControllerProvider);

    // Initialize color with auto-generated or saved color
    if (profile.hasValue && profile.value != null) {
      isNewProfile = false;
      _selectedColor = Color(
          int.parse('0xFF${profile.value!.effectiveTrailColor.substring(1)}'));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _firstNameController.text = profile.value!.firstName;
        _lastNameController.text = profile.value!.lastName!;
        ref.read(_photoProvider.notifier).state = profile.value!.photo;
        _initialTrailColor = profile.value!.trailColor;
      });
    } else {
      isNewProfile = true;
      final generatedColor = UserProfile.generateTrailColor(session!.user.id);
      _selectedColor = Color(int.parse('0xFF${generatedColor.substring(1)}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        _firstNameController.text = next.value!.firstName;
        _lastNameController.text = next.value!.lastName!;
        ref.read(_photoProvider.notifier).state = next.value!.photo;

        // Update trail color if changed
        if (next.value!.trailColor != null &&
            next.value!.trailColor != _initialTrailColor) {
          _initialTrailColor = next.value!.trailColor;
          setState(() {
            _selectedColor = Color(int.parse(
                '0xFF${next.value!.effectiveTrailColor.substring(1)}'));
          });
        }
      }
    });

    return AppScaffold(
        title: isNewProfile ? 'Set up your profile' : 'Update your profile',
        loadMask: submitted ? 'Saving profile...' : null,
        showDrawer: isNewProfile ? false : null,
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
                  const SizedBox(height: 32),
                  ListTile(
                    title: const Text('Trail Color'),
                    subtitle: const Text(
                        'Choose the color for your map trail and icon'),
                    trailing: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                    onTap: _openColorPicker,
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
