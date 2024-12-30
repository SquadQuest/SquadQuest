import 'package:flutter/material.dart';

class FriendsEmptyState extends StatelessWidget {
  final VoidCallback onAddFriend;

  const FriendsEmptyState({
    super.key,
    required this.onAddFriend,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Friends Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add friends to plan activities together and see what they\'re up to!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAddFriend,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Your First Friend'),
            ),
          ],
        ),
      ),
    );
  }
}
