import 'dart:math';

import 'package:flutter/material.dart';

class AppBottomSheet extends StatelessWidget {
  final double? height;
  final String title;
  final bool divider;
  final Widget? leftWidget;
  final Widget? rightWidget;
  final List<Widget> children;
  final double bottomPaddingExtra;
  final bool bottomPaddingInset;
  final double bottomPaddingInsetExtra;
  final bool bottomPaddingSafeArea;

  const AppBottomSheet({
    super.key,
    this.height,
    required this.title,
    this.divider = true,
    this.leftWidget,
    this.rightWidget,
    required this.children,
    this.bottomPaddingExtra = 0,
    this.bottomPaddingInset = true,
    this.bottomPaddingInsetExtra = 0,
    this.bottomPaddingSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: height,
      padding: EdgeInsets.only(
        bottom: bottomPaddingExtra +
            max(
              bottomPaddingInset ? mediaQuery.viewInsets.bottom : 0,
              bottomPaddingSafeArea ? mediaQuery.viewPadding.bottom : 0,
            ) +
            (mediaQuery.viewInsets.bottom > 0 ? bottomPaddingInsetExtra : 0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (leftWidget != null)
                Positioned(
                  left: 12,
                  child: leftWidget!,
                ),
              Positioned(
                right: 12,
                child: rightWidget ??
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          if (divider) const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}
