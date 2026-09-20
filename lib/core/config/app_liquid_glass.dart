import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLiquidGlass {
  static const bool enabled = true;

  static bool get isIos {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  static const double blurSigma = 14;
  static const double interior = 4;
  static const double band = 16;
  static const double ior = 1.5;
  static const double refraction = 20;
  static const double spread = 1;
  static const double chroma = 0.08;
  static const double saturation = 1.42;
  static const double adaptive = 0.38;
  static const double specular = 0.5;
  static const double rimAlpha = 0.85;
  static const double bounceAlpha = 0.16;
  static const double depthShade = 0.14;
  static const double rimWidth = 6;
  static const Offset light = Offset(-0.4, -1);
  static const double tintFeather = 44;

  static Color navTint(ColorScheme cs) =>
      cs.surfaceContainerHigh.withValues(alpha: isIos ? 0.34 : 0.2);

  static Color panelTint(ColorScheme cs) =>
      cs.surface.withValues(alpha: isIos ? 0.36 : 0.24);
}

@immutable
class GlassPreset {
  const GlassPreset({
    required this.blurSigma,
    required this.interior,
    required this.band,
    required this.refraction,
    required this.rimAlpha,
    required this.bounceAlpha,
    required this.saturation,
    required this.adaptive,
    required this.rimWidth,
  });

  final double blurSigma;
  final double interior;
  final double band;
  final double refraction;
  final double rimAlpha;
  final double bounceAlpha;
  final double saturation;
  final double adaptive;
  final double rimWidth;

  static const GlassPreset control = GlassPreset(
    blurSigma: 12,
    interior: 3,
    band: 13,
    refraction: 16,
    rimAlpha: 0.9,
    bounceAlpha: 0.18,
    saturation: 1.55,
    adaptive: 0.34,
    rimWidth: 5,
  );

  static const GlassPreset panel = GlassPreset(
    blurSigma: 18,
    interior: 5,
    band: 22,
    refraction: 26,
    rimAlpha: 0.7,
    bounceAlpha: 0.12,
    saturation: 1.4,
    adaptive: 0.3,
    rimWidth: 8,
  );

  static const GlassPreset iosControl = GlassPreset(
    blurSigma: 16,
    interior: 4,
    band: 12,
    refraction: 14,
    rimAlpha: 0.94,
    bounceAlpha: 0.16,
    saturation: 1.32,
    adaptive: 0.46,
    rimWidth: 5,
  );

  static const GlassPreset iosPanel = GlassPreset(
    blurSigma: 20,
    interior: 6,
    band: 20,
    refraction: 22,
    rimAlpha: 0.78,
    bounceAlpha: 0.1,
    saturation: 1.28,
    adaptive: 0.42,
    rimWidth: 7,
  );

  static GlassPreset get resolvedControl =>
      AppLiquidGlass.isIos ? iosControl : control;

  static GlassPreset get resolvedPanel =>
      AppLiquidGlass.isIos ? iosPanel : panel;
}
