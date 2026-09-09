import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'desktop_ui_scale.dart';
import 'desktop_density_mode.dart';
import '../design/komet_layout.dart';

/// Desktop-only metrics. Mobile list/composer canons stay untouched.
/// Values are the 100% baseline; [s] applies [DesktopUiScale].
class DesktopDensity {
  DesktopDensity._();

  static bool get enabled {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  static double get s => enabled ? DesktopUiScale.current : 1.0;

  static double scaled(double value) => value * s;

  static const double railWidthBase = KometLayout.rail;
  static const double infoPaneWidthBase = KometLayout.inspector;
  static const double infoPaneMinWindow = 1280;
  static const double rowInnerHeightBase = 48;
  static const double avatarRadiusBase = 22;
  static const double titleSizeBase = 14.5;
  static const double previewSizeBase = 13;
  static const double timeSizeBase = 12;
  static const FontWeight titleWeight = FontWeight.w600;

  static double get railWidth => railWidthBase * s;
  static double get infoPaneWidth => infoPaneWidthBase * s;
  static bool get compact =>
      AppDesktopDensity.current.value == DesktopDensityMode.compact;
  static double get rowInnerHeight => (compact ? 40 : rowInnerHeightBase) * s;
  static double get avatarRadius => (compact ? 18 : avatarRadiusBase) * s;
  static double get titleSize => titleSizeBase * s;
  static double get previewSize => previewSizeBase * s;
  static double get timeSize => timeSizeBase * s;
}
