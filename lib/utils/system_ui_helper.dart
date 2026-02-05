import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemUiHelper {
  static SystemUiOverlayStyle overlayStyleForBackground(Color background) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return overlayStyleForBrightness(brightness);
  }

  static SystemUiOverlayStyle overlayStyleForBrightness(
    Brightness backgroundBrightness,
  ) {
    final iconBrightness = backgroundBrightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: backgroundBrightness,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }
}
