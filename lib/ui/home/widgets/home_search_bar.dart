import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeSearchBar extends ConsumerWidget {
  final bool isVisible;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const HomeSearchBar({
    super.key,
    required this.isVisible,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: isVisible ? 72 : 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isVisible ? 1.0 : 0.0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search events...',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
