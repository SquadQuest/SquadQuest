import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/services/router.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  final String? redirect;

  const VerifyScreen({super.key, this.redirect});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _focusNode = FocusNode();

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

    final theme = Theme.of(context);
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 64,
      textStyle: theme.typography.white.displayLarge,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(40),
      ),
    );

    return AppScaffold(
      title: 'Verify phone number',
      loadMask: submitted ? 'Verifying code...' : null,
      showLocationSharingSheet: false,
      bodyPadding: const EdgeInsets.all(16),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(
              'Enter the code sent to the number',
              style: theme.inputDecorationTheme.hintStyle,
            ),
            const SizedBox(height: 16),
            Text(
              formatPhone(authController.verifyingPhone!),
              style: theme.typography.tall.bodyLarge,
            ),
            const SizedBox(height: 32),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Pinput(
                controller: _tokenController,
                focusNode: _focusNode,
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
              ),
            ),
            const SizedBox(height: 32),
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
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
