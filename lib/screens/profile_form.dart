import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/router.dart';
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

  Future<void> _pickPhoto() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      ref.read(_photoProvider.notifier).state =
          kIsWeb ? Uri.parse(pickedFile.path) : File(pickedFile.path).uri;
    }
  }

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
    ref.read(routerProvider).goInitialLocation(widget.redirect);
  }

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick your trail color'),
          content: SingleChildScrollView(
            child: MaterialPicker(
                pickerColor: _selectedColor,
                onColorChanged: (Color color) {
                  setState(() {
                    _selectedColor = color;
                  });
                }),
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

    final photo = ref.watch(_photoProvider);

    return AppScaffold(
      title: isNewProfile ? 'Create Profile' : 'Edit Profile',
      loadMask: submitted ? 'Saving profile...' : null,
      showDrawer: isNewProfile ? false : null,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // Profile Photo Section
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    height: isNewProfile ? 280 : 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.8, 1.0],
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.5),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 36,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            photo != null
                                ? Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 64,
                                        backgroundImage:
                                            kIsWeb || !photo.isScheme('file')
                                                ? NetworkImage(photo.toString())
                                                : FileImage(File(
                                                    Uri.decodeComponent(
                                                        photo.path))),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer,
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => ref
                                                .read(_photoProvider.notifier)
                                                .state = null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 64,
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceVariant,
                                        child:
                                            const Icon(Icons.person, size: 64),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            onPressed: _pickPhoto,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                        if (isNewProfile) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Welcome to SquadQuest!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Tell us a bit about yourself to get started',
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Info Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Basic Information',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _firstNameController,
                              decoration: InputDecoration(
                                labelText: 'First Name',
                                hintText: 'Enter your first name',
                                prefixIcon: const Icon(Icons.person_outline),
                                filled: false,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.3),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your first name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: InputDecoration(
                                labelText: 'Last Name',
                                hintText: 'Enter your last name',
                                prefixIcon: const Icon(Icons.person_outline),
                                filled: false,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.3),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your last name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Your last name will only be visible to confirmed friends',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Appearance Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appearance',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              title: const Text('Trail Color'),
                              subtitle: const Text(
                                  'Choose the color for your map trail'),
                              trailing: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _selectedColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _selectedColor.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              onTap: _openColorPicker,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () => _submitProfile(context),
                        child: Text(
                          isNewProfile ? 'Get Started' : 'Save Changes',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
