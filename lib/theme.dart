import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:squadquest/utils/text_theme_color.dart";

class SquadQuestTheme {
  static String bodyFontName = 'Inter Tight';
  static TextTheme bodyTextTheme = GoogleFonts.getTextTheme(bodyFontName);
  static TextTheme combinedTextTheme = GoogleFonts.getTextTheme(
    displayFontName,
  ).copyWith(
    bodyLarge: bodyTextTheme.bodyLarge,
    bodyMedium: bodyTextTheme.bodyMedium,
    bodySmall: bodyTextTheme.bodySmall,
    labelLarge: bodyTextTheme.labelLarge,
    labelMedium: bodyTextTheme.labelMedium,
    labelSmall: bodyTextTheme.labelSmall,
  );

  static ThemeData dark = ThemeData(
    colorScheme: darkColorScheme,
    primaryTextTheme: textTheme.apply(bodyColor: darkColorScheme.onPrimary),
    textTheme: textTheme,
  );

  static ColorScheme darkColorScheme =
      ColorScheme.fromSeed(brightness: Brightness.dark, seedColor: seedColor);

  static String displayFontName = 'Aleo';
  static ThemeData light = ThemeData(
    colorScheme: lightColorScheme,
    primaryTextTheme: textTheme,
    textTheme: textTheme,
  );

  static ColorScheme lightColorScheme =
      ColorScheme.fromSeed(seedColor: seedColor);

  static Color seedColor = const Color(0xffA87337);
  static TextTheme textTheme = TextThemeColor.nullFontColor(combinedTextTheme);
}
