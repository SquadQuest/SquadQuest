import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_controller.dart';

/// Phone-OTP login (specs/api/auth.md). Two steps driven by AuthState:
/// SignedOut → phone entry; AwaitingOtp → code entry.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final awaitingOtp = auth is AwaitingOtp;

    return Scaffold(
      appBar: AppBar(title: const Text('SquadQuest')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  awaitingOtp ? 'Enter your code' : 'Sign in',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!awaitingOtp) ...[
                  TextField(
                    key: const Key('phoneField'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '+1 215 555 0100',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('requestOtpButton'),
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => ref
                                .read(authControllerProvider.notifier)
                                .requestOtp(_phone.text.trim()),
                          ),
                    child: Text(_busy ? 'Sending…' : 'Send code'),
                  ),
                ] else ...[
                  Text(
                    'We texted a code to ${auth.phone}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('codeField'),
                    controller: _code,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: '123456',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('verifyOtpButton'),
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => ref
                                .read(authControllerProvider.notifier)
                                .verifyOtp(_code.text.trim()),
                          ),
                    child: Text(_busy ? 'Verifying…' : 'Verify'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .cancelOtp(),
                    child: const Text('Use a different number'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    key: const Key('loginError'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
