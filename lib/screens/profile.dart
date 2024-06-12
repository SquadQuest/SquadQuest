import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squad_quest/drawer.dart';
import 'package:squad_quest/controllers/auth.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool submitted = false;

  void _submitProfile(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      submitted = true;
    });

    try {
      await ref.read(authControllerProvider.notifier).updateProfile({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
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

    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
              'Set up your profile'), // TODO: vary based on profile state
        ),
        drawer: const AppDrawer(), // TODO: hide if profile is not initialized
        body: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
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
                const SizedBox(height: 16),
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
                      )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
