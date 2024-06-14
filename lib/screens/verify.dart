import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';

final RegExp otpCodeRegExp = RegExp(r'^\d{6}$');

class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key});

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
    log('Verifying token');

    final authController = ref.read(authControllerProvider.notifier);

    try {
      await authController.verifyOTP(
        token: token,
      );
      log('Verified token');
    } catch (error) {
      log('Error verifying token: $error');

      setState(() {
        submitted = false;
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to verify, check code and try again:\n\n$error'),
      ));

      return;
    }

    final profile = await ref.read(profileProvider.notifier).fetch();

    if (!context.mounted) return;

    context.go(profile == null ? '/profile' : '/');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verify phone number'),
        ),
        body: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  autofocus: true,
                  readOnly: submitted,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.pin_outlined),
                    labelText: 'Enter the code sent to your phone',
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
                submitted
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed:
                            submitted ? null : () => _submitToken(context),
                        child: const Text(
                          'Verify',
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
