import 'package:flutter/material.dart';

final appThemeLight = ThemeData.light(useMaterial3: true).copyWith(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4), // Primary purple
    secondary: const Color(0xFF03DAC6), // Teal accent
    brightness: Brightness.light,
    background: const Color(0xFFFAF9FB), // Subtle purple tint
    surface: const Color(0xFFF6F5F7),
    surfaceVariant: const Color(0xFFE7E0EC),
    primaryContainer: const Color(0xFFEADDFF), // Light purple container
    secondaryContainer: const Color(0xFFCEF6F0), // Light teal container
  ),
  extensions: <ThemeExtension<dynamic>>[
    const SquadQuestColors(
      locationSharingBottomSheetActiveBackgroundColor: Color(0xFF81C784),
      locationSharingBottomSheetAvailableBackgroundColor: Color(0xFFFFB74D),
      locationSharingBottomSheetTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 16,
      ),
    ),
  ],
);

final appThemeDark = ThemeData.dark(useMaterial3: true).copyWith(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFD0BCFF), // Brighter purple for dark theme
    secondary: const Color(0xFF03DAC6), // Bright teal
    brightness: Brightness.dark,
    background:
        const Color(0xFF1C1B1F), // Deep background with purple undertone
    surface: const Color(0xFF2B2930),
    surfaceVariant: const Color(0xFF49454F),
    primaryContainer: const Color(0xFF4F378B), // Rich purple container
    secondaryContainer: const Color(0xFF00867D), // Rich teal container
    onPrimaryContainer: const Color(0xFFEADDFF),
    onSecondaryContainer: const Color(0xFFA6F0E8),
  ),
  extensions: <ThemeExtension<dynamic>>[
    const SquadQuestColors(
      locationSharingBottomSheetActiveBackgroundColor: Color(0xFF2E7D32),
      locationSharingBottomSheetAvailableBackgroundColor: Color(0xFFF57C00),
      locationSharingBottomSheetTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
    ),
  ],
);

@immutable
class SquadQuestColors extends ThemeExtension<SquadQuestColors> {
  final Color? locationSharingBottomSheetActiveBackgroundColor;
  final Color? locationSharingBottomSheetAvailableBackgroundColor;
  final TextStyle? locationSharingBottomSheetTextStyle;

  const SquadQuestColors({
    required this.locationSharingBottomSheetActiveBackgroundColor,
    required this.locationSharingBottomSheetAvailableBackgroundColor,
    required this.locationSharingBottomSheetTextStyle,
  });

  @override
  SquadQuestColors copyWith({
    Color? locationSharingBottomSheetActiveBackgroundColor,
    Color? locationSharingBottomSheetAvailableBackgroundColor,
    TextStyle? locationSharingBottomSheetTextStyle,
  }) {
    return SquadQuestColors(
      locationSharingBottomSheetActiveBackgroundColor:
          locationSharingBottomSheetActiveBackgroundColor ??
              this.locationSharingBottomSheetActiveBackgroundColor,
      locationSharingBottomSheetAvailableBackgroundColor:
          locationSharingBottomSheetAvailableBackgroundColor ??
              this.locationSharingBottomSheetAvailableBackgroundColor,
      locationSharingBottomSheetTextStyle:
          locationSharingBottomSheetTextStyle ??
              this.locationSharingBottomSheetTextStyle,
    );
  }

  @override
  SquadQuestColors lerp(SquadQuestColors? other, double t) {
    if (other is! SquadQuestColors) {
      return this;
    }
    return SquadQuestColors(
      locationSharingBottomSheetActiveBackgroundColor: Color.lerp(
        locationSharingBottomSheetActiveBackgroundColor,
        other.locationSharingBottomSheetActiveBackgroundColor,
        t,
      ),
      locationSharingBottomSheetAvailableBackgroundColor: Color.lerp(
        locationSharingBottomSheetAvailableBackgroundColor,
        other.locationSharingBottomSheetAvailableBackgroundColor,
        t,
      ),
      locationSharingBottomSheetTextStyle: TextStyle(
        color: Color.lerp(
          locationSharingBottomSheetTextStyle!.color,
          other.locationSharingBottomSheetTextStyle!.color,
          t,
        ),
        fontSize: locationSharingBottomSheetTextStyle!.fontSize! +
            (other.locationSharingBottomSheetTextStyle!.fontSize! -
                    locationSharingBottomSheetTextStyle!.fontSize!) *
                t,
      ),
    );
  }
}
