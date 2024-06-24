import 'package:flutter/material.dart';

final appThemeLight = ThemeData.light(useMaterial3: true).copyWith(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.orange.shade200,
    brightness: Brightness.light,
  ),
  extensions: <ThemeExtension<dynamic>>[
    const SquadQuestColors(
        locationSharingBottomSheetBackgroundColor:
            Color.fromRGBO(129, 199, 132, 1),
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
        locationSharingBottomSheetBackgroundColor:
            Color.fromRGBO(27, 94, 32, 1),
        locationSharingBottomSheetTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ))
  ],
);

@immutable
class SquadQuestColors extends ThemeExtension<SquadQuestColors> {
  final Color? locationSharingBottomSheetBackgroundColor;
  final TextStyle? locationSharingBottomSheetTextStyle;

  const SquadQuestColors({
    required this.locationSharingBottomSheetBackgroundColor,
    required this.locationSharingBottomSheetTextStyle,
  });

  @override
  SquadQuestColors copyWith(
      {Color? locationSharingBottomSheetBackgroundColor,
      TextStyle? locationSharingBottomSheetTextStyle}) {
    return SquadQuestColors(
      locationSharingBottomSheetBackgroundColor:
          locationSharingBottomSheetBackgroundColor ??
              this.locationSharingBottomSheetBackgroundColor,
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
      locationSharingBottomSheetBackgroundColor: Color.lerp(
          locationSharingBottomSheetBackgroundColor,
          other.locationSharingBottomSheetBackgroundColor,
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
