import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'glass_intensity.dart';

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

  /// True when the platform asked for reduced transparency: panels then go
  /// solid instead of merely losing their blur, which would leave translucent
  /// surfaces with nothing behind them to stay readable against.
  static bool get _opaque => !GlassIntensity.systemAllowsBlur.value;

  /// Blur radii carry the user's glass intensity.
  static double get sigma => _scaled(_softDesktop ? 14 : 34);
  static double get panelSigma => _scaled(_softDesktop ? 12 : 24);
  static double get mediaBackdropSigma => _scaled(_softDesktop ? 12 : 30);

  static double _scaled(double value) =>
      _opaque ? 0 : value * GlassIntensity.factor;

  static Color glassTint(ColorScheme cs, [double alpha = glassAlpha]) =>
      cs.surfaceContainerHigh.withValues(alpha: _opaque ? 1 : alpha);

  static Color blurPanelTint(ColorScheme cs) => glassTint(cs, blurPanelAlpha);

  static Color scrim([double alpha = scrimAlpha]) =>
      Colors.black.withValues(alpha: alpha);

  static BorderSide hairline(ColorScheme cs) =>
      BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5);
}
