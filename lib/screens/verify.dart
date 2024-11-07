import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/services/router.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';

final RegExp otpCodeRegExp = RegExp(r'^\d{6}$');

class VerifyScreen extends ConsumerStatefulWidget {
  final String? redirect;

  const VerifyScreen({super.key, this.redirect});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();

  bool submitted = false;

  void _submitToken(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      submitted = true;
    });

    final token = _tokenController.text.trim();
    log('Verifying OTP');

    final authController = ref.read(authControllerProvider.notifier);

    try {
      await authController.verifyOTP(
        token: token,
      );
      log('Verified OTP');
    } catch (error) {
      log('Error verifying OTP: $error');

      setState(() {
        submitted = false;
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to verify, check code and try again:\n\n$error'),
      ));

      return;
    }

    await ref.read(profileProvider.notifier).fetch();

    ref.read(routerProvider).goInitialLocation(widget.redirect);
  }

  @override
  Widget build(BuildContext context) {
    final authController = ref.read(authControllerProvider.notifier);

    return AppScaffold(
      title: 'Verify phone number',
      loadMask: submitted ? 'Verifying code...' : null,
      showLocationSharingSheet: false,
      bodyPadding: const EdgeInsets.all(16),
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                autofocus: true,
                readOnly: submitted,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.pin_outlined),
                  labelText:
                      'Enter the code sent to ${formatPhone(authController.verifyingPhone!)}',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[^0-9]'))
                ],
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      !otpCodeRegExp.hasMatch(value)) {
                    return 'Please enter a valid one-time password';
                  }
                  return null;
                },
                controller: _tokenController,
                onFieldSubmitted: (_) => _submitToken(context),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: submitted ? null : () => _submitToken(context),
                child: const Text(
                  'Verify',
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
