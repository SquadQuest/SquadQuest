import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/controllers/auth.dart';
import 'verify.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  static const routeName = '/login';

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool submitted = false;

  void _submitPhone(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      submitted = true;
    });

    final phone = _phoneController.text.trim();
    log('Sending login code via SMS to $phone');

    try {
      await ref.read(authControllerProvider.notifier).signInWithOtp(
            phone: phone,
          );
      log('Sent SMS');
    } catch (error) {
      log('Error sending SMS: $error');

      setState(() {
        submitted = false;
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Failed to login, check phone number and try again:\n\n$error'),
      ));

      return;
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerifyView(phone: phone),
      ),
    ).whenComplete(() {
      setState(() {
        submitted = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in to SquadQuest'),
      ),
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                readOnly: submitted,
                autofillHints: const [AutofillHints.telephoneNumber],
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.phone),
                  labelText: 'Enter your phone number',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
                controller: _phoneController,
              ),
              const SizedBox(height: 16),
              submitted
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: submitted ? null : () => _submitPhone(context),
                      child: const Text(
                        'Send login code via SMS',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    )
            ],
          ),
        ),
      ),
    );
  }
}
