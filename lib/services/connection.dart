import 'package:flutter/material.dart';

import 'package:squadquest/services/router.dart';

class ConnectionService {
  static Future<void> showConnectionErrorDialog() {
    return showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unable to connect'),
          content: const Text(
              'SquadQuest is unable to connect to the server. Please check your internet connection and try again.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
