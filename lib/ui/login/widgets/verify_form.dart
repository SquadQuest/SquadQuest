import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/controllers/auth.dart';

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
    final theme = Theme.of(context);
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 64,
      textStyle: theme.typography.white.displayLarge,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(40),
      ),
    );

    return Consumer(
      builder: (context, ref, child) {
        final authController = ref.read(authControllerProvider.notifier);

        return Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(width: double.infinity),
              Text(
                'Enter the code sent to the number:',
                style: theme.inputDecorationTheme.hintStyle,
              ),
              const SizedBox(height: 8),
              Text(
                formatPhone(authController.verifyingPhone!),
                style: theme.typography.tall.bodyLarge,
              ),
              const SizedBox(height: 16),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Pinput(
                  controller: _tokenController,
                  length: 6,
                  hapticFeedbackType: HapticFeedbackType.heavyImpact,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[^0-9]'))
                  ],
                  textInputAction: TextInputAction.done,
                  separatorBuilder: (index) => Container(
                    height: 64,
                    width: 1,
                    color: theme.scaffoldBackgroundColor,
                  ),
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(80),
                    ),
                  ),
                  onSubmitted: widget.submitted ? null : (_) => _submitToken(),
                  onCompleted: widget.submitted ? null : (_) => _submitToken(),
                ),
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
