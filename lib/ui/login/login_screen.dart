import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/connection.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';

import 'widgets/login_form.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? redirect;

  const LoginScreen({super.key, this.redirect});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool submitted = false;

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
        context.pushNamed('verify',
            queryParameters:
                widget.redirect == null ? {} : {'redirect': widget.redirect});
      }
    } on AuthRetryableFetchException catch (_) {
      await ConnectionService.showConnectionErrorDialog();
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
      body: LoginForm(
        onSubmit: _submitPhone,
        submitted: submitted,
      ),
    );
  }
}
