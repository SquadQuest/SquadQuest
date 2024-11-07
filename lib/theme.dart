import 'package:flutter/material.dart';

final appThemeLight = ThemeData.light(useMaterial3: true).copyWith(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.orange.shade200,
    brightness: Brightness.light,
  ),
  extensions: <ThemeExtension<dynamic>>[
    const SquadQuestColors(
        locationSharingBottomSheetActiveBackgroundColor:
            Color.fromRGBO(129, 199, 132, 1),
        locationSharingBottomSheetAvailableBackgroundColor:
            Color.fromRGBO(255, 235, 59, 1),
        locationSharingBottomSheetTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 16,
        )),
  ],
);

final appThemeDark = ThemeData.dark(useMaterial3: true).copyWith(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.orange,
    brightness: Brightness.dark,
  ),
  extensions: <ThemeExtension<dynamic>>[
    const SquadQuestColors(
        locationSharingBottomSheetActiveBackgroundColor:
            Color.fromRGBO(27, 94, 32, 1),
        locationSharingBottomSheetAvailableBackgroundColor:
            Color.fromRGBO(245, 127, 23, 1),
        locationSharingBottomSheetTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ))
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
  SquadQuestColors copyWith(
      {Color? locationSharingBottomSheetActiveBackgroundColor,
      Color? locationSharingBottomSheetAvailableBackgroundColor,
      TextStyle? locationSharingBottomSheetTextStyle}) {
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
          t),
      locationSharingBottomSheetAvailableBackgroundColor: Color.lerp(
          locationSharingBottomSheetAvailableBackgroundColor,
          other.locationSharingBottomSheetAvailableBackgroundColor,
          t),
      locationSharingBottomSheetTextStyle: TextStyle(
        color: Color.lerp(locationSharingBottomSheetTextStyle!.color,
            other.locationSharingBottomSheetTextStyle!.color, t),
        fontSize: locationSharingBottomSheetTextStyle!.fontSize! +
            (other.locationSharingBottomSheetTextStyle!.fontSize! -
                    locationSharingBottomSheetTextStyle!.fontSize!) *
                t,
      ),
    );
  }
}
