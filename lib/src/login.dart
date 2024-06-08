import 'dart:developer';
import 'package:flutter/material.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool submitted = false;

  void _submitPhone() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      submitted = true;
    });

    final phone = _phoneController.text.trim();
    log('Send login code via SMS to $phone');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in to SquadQuest'),
      ),
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            // crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                readOnly: submitted,
                autofillHints: const [AutofillHints.telephoneNumber],
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.phone),
                  labelText: 'Enter your phone number',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
                controller: _phoneController,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: submitted ? null : _submitPhone,
                child: const Text(
                  'Send login code via SM',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
