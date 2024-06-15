import 'package:flutter/material.dart';

final appThemeLight = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.orange.shade200,
    brightness: Brightness.light,
  ),
);

final appThemeDark = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.orange,
    brightness: Brightness.dark,
  ),
);
