import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/components/phone_number_field.dart';

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
        context.pushNamed('verify',
            queryParameters:
                widget.redirect == null ? {} : {'redirect': widget.redirect});
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
      loadMask: submitted ? 'Sending login code...' : null,
      showLocationSharingSheet: false,
      bodyPadding: const EdgeInsets.all(16),
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
              ElevatedButton(
                onPressed: submitted ? null : () => _submitPhone(context),
                child: const Text(
                  'Send login code via SMS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
