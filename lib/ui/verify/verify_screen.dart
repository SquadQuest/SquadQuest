import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/router.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';

import 'widgets/verify_form.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  final String? redirect;

  const VerifyScreen({super.key, this.redirect});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  bool submitted = false;

  void _submitToken(String token) async {
    setState(() {
      submitted = true;
    });

    log('Verifying OTP');

    final authController = ref.read(authControllerProvider.notifier);

    try {
      await authController.verifyOTP(
        token: token,
      );
      log('Verified OTP');
    } catch (error, stackTrace) {
      logger.e('Error verifying OTP', error: error, stackTrace: stackTrace);
      final errorMessage = switch (error) {
        AuthException(:final message) => message,
        _ => 'Unexpected error',
      };

      setState(() {
        submitted = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Failed to verify, check code and try again:\n\n$errorMessage'),
        ));
      }

      return;
    }

    await ref.read(profileProvider.notifier).fetch();

    ref.read(routerProvider).goInitialLocation(widget.redirect);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Verify phone number',
      loadMask: submitted ? 'Verifying code...' : null,
      showLocationSharingSheet: false,
      bodyPadding: const EdgeInsets.all(16),
      body: VerifyForm(
        submitted: submitted,
        onSubmit: _submitToken,
      ),
    );
  }
}
