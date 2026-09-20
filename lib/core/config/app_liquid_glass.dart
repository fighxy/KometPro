import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLiquidGlass {
  static const bool enabled = true;

  static bool get _ios {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  static const double blurSigma = 14;
  static const double interior = 4;
  static const double band = 16;
  static const double ior = 1.5;
  static const double refraction = 20;
  static const double spread = 1;
  static const double specular = 0.5;
  static const double rimAlpha = 0.85;
  static const double bounceAlpha = 0.16;
  static const double rimWidth = 6;
  static const Offset light = Offset(-0.4, -1);
  static const double tintFeather = 44;

  static double get chroma => _ios ? 0.07 : 0.12;
  static double get adaptive => _ios ? 0.42 : 0.3;
  static double get depthShade => _ios ? 0.18 : 0.1;
  static double get saturation => _ios ? 1.38 : 1.5;

  static Color navTint(ColorScheme cs) =>
      cs.surfaceContainerHigh.withValues(alpha: _ios ? 0.34 : 0.2);

  static Color panelTint(ColorScheme cs) =>
      cs.surface.withValues(alpha: _ios ? 0.36 : 0.24);
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
    this.chroma,
    this.depthShade,
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
  final double? chroma;
  final double? depthShade;

  static GlassPreset get control => AppLiquidGlass._ios ? _iosControl : _control;
  static GlassPreset get panel => AppLiquidGlass._ios ? _iosPanel : _panel;

  static const GlassPreset _control = GlassPreset(
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

  static const GlassPreset _panel = GlassPreset(
    blurSigma: 18,
    interior: 5,
    band: 22,
    refraction: 26,
    rimAlpha: 0.7,
    bounceAlpha: 0.12,
    saturation: 1.4,
    adaptive: 0.3,
    rimWidth: 8,
  );n
  static const GlassPreset _iosControl = GlassPreset(
    blurSigma: 16,
    interior: 3,
    band: 12,
    refraction: 14,
    rimAlpha: 0.96,
    bounceAlpha: 0.22,
    saturation: 1.36,
    adaptive: 0.46,
    rimWidth: 6,
    chroma: 0.06,
    depthShade: 0.2,
  );

  static const GlassPreset _iosPanel = GlassPreset(
    blurSigma: 22,
    interior: 6,
    band: 20,
    refraction: 18,
    rimAlpha: 0.82,
    bounceAlpha: 0.16,
    saturation: 1.28,
    adaptive: 0.4,
    rimWidth: 8,
    chroma: 0.05,
    depthShade: 0.18,
  );
}
