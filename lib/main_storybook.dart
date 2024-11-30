import 'package:flutter/material.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';

void main() {
  runApp(const StorybookApp());
}

class StorybookApp extends StatelessWidget {
  const StorybookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Storybook(
      stories: [
        Story(
          name: 'Example Story',
          builder: (context) => const Center(
            child: Text('Hello Storybook!'),
          ),
        ),
      ],
    );
  }
}
