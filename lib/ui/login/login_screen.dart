import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/connection.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/profile.dart';

import 'widgets/phone_form.dart';
import 'widgets/verify_form.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool submitted = false;
  final _navigatorKey = GlobalKey<NavigatorState>();

  void _submitPhone(String phone) async {
    setState(() {
      submitted = true;
    });

    log('Sending login code via SMS to $phone');

    try {
      await ref.read(authControllerProvider.notifier).signInWithOtp(
            phone: phone,
          );
      log('Sent SMS');

      if (mounted) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => AppScaffold(
              title: 'Verify phone number',
              loadMask: submitted ? 'Verifying code...' : null,
              showLocationSharingSheet: false,
              bodyPadding: const EdgeInsets.all(16),
              body: VerifyForm(
                submitted: submitted,
                onSubmit: _submitToken,
              ),
            ),
          ),
        );
      }
    } on AuthRetryableFetchException catch (_) {
      await ConnectionService.showConnectionErrorDialog();
    } catch (error, stackTrace) {
      logger.e('Error sending SMS', error: error, stackTrace: stackTrace);
      final errorMessage = switch (error) {
        AuthException(:final message) => message,
        _ => 'Unexpected error',
      };

      if (mounted) {
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

      if (mounted) {
        setState(() {
          submitted = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Failed to verify, check code and try again:\n\n$errorMessage'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      pages: [
        MaterialPage(
          child: AppScaffold(
            title: 'Log in to SquadQuest',
            loadMask: submitted ? 'Sending login code...' : null,
            showLocationSharingSheet: false,
            bodyPadding: const EdgeInsets.all(16),
            body: PhoneForm(
              onSubmit: _submitPhone,
              submitted: submitted,
            ),
          ),
        ),
      ],
      onDidRemovePage: (Page<Object?> page) {},
    );
  }
}
