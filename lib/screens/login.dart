import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
        context
            .pushNamed('verify',
                queryParameters: widget.redirect == null
                    ? {}
                    : {'redirect': widget.redirect})
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
              submitted
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: submitted ? null : () => _submitPhone(context),
                      child: const Text(
                        'Send login code via SMS',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
              if (kIsWeb) ...[
                const Spacer(),
                const Text('Install the app instead for the best experience:'),
                Row(children: [
                  Expanded(
                      flex: 1,
                      child: Padding(
                          padding: const EdgeInsets.only(
                              right: 12, top: 16, bottom: 16),
                          child: InkWell(
                              onTap: () => launchUrl(Uri.parse(
                                  'https://play.google.com/store/apps/details?id=app.squadquest')),
                              child: Image.asset(
                                  'assets/images/app-stores/google-dark-on-white.png')))),
                  Expanded(
                      flex: 1,
                      child: Padding(
                          padding: const EdgeInsets.only(
                              left: 12, top: 16, bottom: 16),
                          child: InkWell(
                              onTap: () => launchUrl(Uri.parse(
                                  'https://apps.apple.com/us/app/squadquest/id6504465196')),
                              child: Image.asset(
                                  'assets/images/app-stores/apple-dark-on-white.png'))))
                ]),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
