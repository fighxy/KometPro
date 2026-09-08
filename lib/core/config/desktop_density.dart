import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Desktop-only metrics. Mobile list/composer canons stay untouched.
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

  static const double railWidth = 60;
  static const double infoPaneWidth = 320;
  static const double infoPaneMinWindow = 1280;
  static const double rowInnerHeight = 48;
  static const double avatarRadius = 22;
  static const double titleSize = 14.5;
  static const double previewSize = 13;
  static const double timeSize = 12;
  static const FontWeight titleWeight = FontWeight.w600;
}
