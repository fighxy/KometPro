import 'package:flutter/material.dart';

class AppLiquidGlass {
  static const bool enabled = true;

  static const double blurSigma = 8;
  static const double spread = 1;
  static const double refraction = 34;
  static const double chroma = 0.35;
  static const double specular = 0.45;
  static const double rimWidth = 8;
  static const Offset light = Offset(-0.4, -1);
  static const double tintFeather = 44;

  static Color navTint(ColorScheme cs) =>
      cs.surfaceContainerHigh.withValues(alpha: 0.18);

  static Color panelTint(ColorScheme cs) => cs.surface.withValues(alpha: 0.24);
}
