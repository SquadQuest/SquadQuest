import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/controllers/auth.dart';

final RegExp otpCodeRegExp = RegExp(r'^\d{6}$');

class VerifyForm extends StatefulWidget {
  final bool submitted;
  final Function(String) onSubmit;

  const VerifyForm({
    super.key,
    required this.submitted,
    required this.onSubmit,
  });

  @override
  State<VerifyForm> createState() => _VerifyFormState();
}

class _VerifyFormState extends State<VerifyForm> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();

  void _submitToken() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final token = _tokenController.text.trim();
    widget.onSubmit(token);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authController = ref.read(authControllerProvider.notifier);

        return Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                autofocus: true,
                readOnly: widget.submitted,
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
                onFieldSubmitted: (_) => _submitToken(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: widget.submitted ? null : _submitToken,
                child: const Text(
                  'Verify',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
