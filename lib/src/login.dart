import 'dart:developer';
import 'package:flutter/material.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in to SquadQuest'),
      ),
      body: AutofillGroup(
        child: Form(
          child: Column(
            // crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
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
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                child: const Text(
                  'Send login code via SM',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  log('Send login code via SMS');
                  // if (_formKey.currentState!.validate()) {
                  //   final phone = _phoneController.text.trim();
                  //   if (isSigningIn) {
                  //     await _supabase.auth.signIn(phone);
                  //   } else {
                  //     await _supabase.auth.signUp(phone);
                  //   }
                  // }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
