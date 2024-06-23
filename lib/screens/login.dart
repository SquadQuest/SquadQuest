import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/controllers/auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? redirect;

  const LoginScreen({super.key, this.redirect});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

    final phone = normalizePhone(_phoneController.text);
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

    context
        .pushNamed('verify',
            queryParameters:
                widget.redirect == null ? {} : {'redirect': widget.redirect})
        .then((_) {
      setState(() {
        submitted = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Log in to SquadQuest'),
        ),
        body: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  autofocus: true,
                  readOnly: submitted,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone),
                    labelText: 'Enter your phone number',
                  ),
                  inputFormatters: [phoneInputFilter],
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        normalizePhone(value).length != 11) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                  controller: _phoneController,
                  onFieldSubmitted: (_) => _submitPhone(context),
                ),
                const SizedBox(height: 16),
                submitted
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed:
                            submitted ? null : () => _submitPhone(context),
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
      ),
    );
  }
}
