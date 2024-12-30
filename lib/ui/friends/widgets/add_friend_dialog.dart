import 'package:flutter/material.dart';

enum AddFriendMethod { number, contacts }

class AddFriendDialog extends StatelessWidget {
  const AddFriendDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Friend'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('By Phone Number'),
            onTap: () {
              Navigator.of(context).pop(AddFriendMethod.number);
            },
          ),
          ListTile(
            leading: const Icon(Icons.contacts),
            title: const Text('From Contacts'),
            onTap: () {
              Navigator.of(context).pop(AddFriendMethod.contacts);
            },
          ),
        ],
      ),
    );
  }
}
