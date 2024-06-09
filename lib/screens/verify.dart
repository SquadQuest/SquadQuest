import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/controllers/auth.dart';

class VerifyView extends ConsumerStatefulWidget {
  const VerifyView({super.key, required this.phone});

  static const routeName = '/login';
  final String phone;

  @override
  ConsumerState<VerifyView> createState() => _VerifyViewState();
}

class _VerifyViewState extends ConsumerState<VerifyView> {
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

    final authController = ref.read(authControllerProvider);

    try {
      await authController.verifyOTP(
        token: token,
        phone: widget.phone,
      );
      log('Verified token');
    } catch (error) {
      log('Error verifying token: $error');

      setState(() {
        submitted = false;
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to verify, check code and try again'),
      ));

      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify phone number'),
      ),
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                readOnly: submitted,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.key),
                  labelText: 'Enter the code sent to your phone',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a valid one-time password';
                  }
                  return null;
                },
                controller: _tokenController,
              ),
              const SizedBox(height: 16),
              submitted
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: submitted ? null : () => _submitToken(context),
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
    );
  }
}
