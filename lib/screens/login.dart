import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_scaffold.dart';
import '../common.dart';
import '../components/phone_number_field.dart';
import '../controllers/auth.dart';
import '../services/supabase.dart';

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

      if (context.mounted) {
        context
            .pushNamed('verify',
                queryParameters: widget.redirect == null ? {} : {'redirect': widget.redirect})
            .then((_) {});
      }
    } catch (error, st) {
      log('Error sending SMS:', error: error, stackTrace: st);
      final errorMessage = switch (error) {
        AuthException(:final message) => message,
        _ => 'Unexpected error',
      };

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Failed to login, check phone number and try again.\n'
            'Details: $errorMessage',
          ),
        ));
      }
    } finally {
      setState(() {
        submitted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Log in to SquadQuest',
      showDrawer: false,
      showLocationSharingSheet: false,
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              PhoneNumberFormField(
                autofocus: true,
                onSubmitted: (_) => _submitPhone(context),
                phoneNumberController: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Enter your phone number',
                ),
              ),
              const SizedBox(height: 16),
              submitted
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: submitted ? null : () => _submitPhone(context),
                      child: const Text(
                        'Send login code via SMS',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    )
            ],
          ),
        ),
      ),
    );
  }
}
