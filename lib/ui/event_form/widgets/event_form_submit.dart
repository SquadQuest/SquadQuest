import 'package:flutter/material.dart';

/// Submit button section for event form.
///
/// Displays a full-width submit button that:
/// - Shows appropriate text based on whether creating or editing
/// - Disables during submission
class EventFormSubmit extends StatelessWidget {
  const EventFormSubmit({
    super.key,
    required this.onSubmit,
    required this.isNewEvent,
    required this.isSubmitting,
  });

  final VoidCallback onSubmit;
  final bool isNewEvent;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              child: Text(
                isNewEvent ? 'Create Event' : 'Save Changes',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
