import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/components/phone_number_field.dart';

class PhoneForm extends ConsumerStatefulWidget {
  final void Function(String) onSubmit;
  final bool submitted;

  const PhoneForm({
    super.key,
    required this.onSubmit,
    required this.submitted,
  });

  @override
  ConsumerState<PhoneForm> createState() => _PhoneFormState();
}

class _PhoneFormState extends ConsumerState<PhoneForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  void _submitPhone() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    widget.onSubmit(_phoneController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          PhoneNumberFormField(
            autofocus: true,
            onSubmitted: (_) => _submitPhone(),
            phoneNumberController: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Enter your phone number',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: widget.submitted ? null : _submitPhone,
            child: const Text(
              'Send login code via SMS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const Spacer(),
          const Text('SquadQuest is focused on privacy.\n\n'
              'Only people who know your phone number already can send you a friend request,'
              ' and only people you\'ve accepted friend requests from can see any of your personal details.'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
