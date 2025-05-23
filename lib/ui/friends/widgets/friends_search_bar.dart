import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FriendsSearchBar extends ConsumerStatefulWidget {
  final bool isVisible;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const FriendsSearchBar({
    super.key,
    required this.isVisible,
    required this.controller,
    required this.onChanged,
  });

  @override
  ConsumerState<FriendsSearchBar> createState() => _FriendsSearchBarState();
}

class _FriendsSearchBarState extends ConsumerState<FriendsSearchBar> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FriendsSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        // Wait for animation to start before focusing
        Future.delayed(const Duration(milliseconds: 50), () {
          _focusNode.requestFocus();
          widget.controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: widget.controller.text.length,
          );
        });
      } else {
        // Immediately unfocus when hiding
        _focusNode.unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: widget.isVisible ? 72 : 0,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.isVisible ? 1.0 : 0.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withAlpha(179),
                ),
                hintStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withAlpha(179),
                ),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
            ),
          ),
        ),
      ),
    );
  }
}
