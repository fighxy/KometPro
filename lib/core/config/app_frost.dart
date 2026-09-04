import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppFrost {
  static const double overlaySigma = 18;
  static const double glassAlpha = 0.28;
  static const double blurPanelAlpha = 0.55;
  static const double scrimAlpha = 0.4;

  static bool get _softDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  static double get sigma => _softDesktop ? 14 : 34;
  static double get panelSigma => _softDesktop ? 12 : 24;
  static double get mediaBackdropSigma => _softDesktop ? 12 : 30;
  static const double blurPanelAlpha = 0.55;
  static const double scrimAlpha = 0.4;

  static Color glassTint(ColorScheme cs, [double alpha = glassAlpha]) =>
      cs.surfaceContainerHigh.withValues(alpha: alpha);

  static Color blurPanelTint(ColorScheme cs) => glassTint(cs, blurPanelAlpha);

  static Color scrim([double alpha = scrimAlpha]) =>
      Colors.black.withValues(alpha: alpha);

  static BorderSide hairline(ColorScheme cs) =>
      BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5);
}
