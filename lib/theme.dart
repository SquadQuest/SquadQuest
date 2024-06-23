import 'package:flutter/material.dart';

final appThemeLight = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.orange.shade200,
    brightness: Brightness.light,
  ),
);

final appThemeDark = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.orange,
    brightness: Brightness.dark,
  ),
);
