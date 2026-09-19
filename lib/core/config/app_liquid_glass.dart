import 'package:flutter/material.dart';

/// Liquid glass material parameters.
///
/// Values follow the optical model Apple's material is built on: a narrow
/// bevel at the rim does the lensing, the body stays lightly frosted, colour
/// behind the glass is amplified rather than greyed out, and a thin specular
/// line rides the lit edge.
class AppLiquidGlass {
  static const bool enabled = true;

  /// Backdrop blur under the shader. It only covers the surface's own rect,
  /// while the rim samples outward, past the clip — so the body can be frosted
  /// hard without softening the magnified edge that makes it read as glass.
  static const double blurSigma = 14;

  /// Extra softening the shader's own gather adds toward the middle, in
  /// logical pixels. Kept small: eight taps cannot stand in for a Gaussian.
  static const double interior = 4;

  /// Width of the bevel that refracts, in logical pixels.
  static const double band = 16;

  /// Refractive index of the slab. Window glass is ~1.5.
  static const double ior = 1.5;

  /// Largest edge displacement in logical pixels.
  static const double refraction = 20;

  /// Multiplier on [band]; per-surface overrides use it to widen or tighten
  /// the lens without changing the profile.
  static const double spread = 1;

  /// Chromatic aberration as a fraction of the local displacement.
  static const double chroma = 0.12;

  /// Colour amplification behind the glass.
  static const double saturation = 1.5;

  /// How much the tint veil grows when the backdrop's brightness is far from
  /// the glass's own tone. This is what keeps labels on the glass readable
  /// over a bright photo without veiling a matching backdrop.
  static const double adaptive = 0.3;

  static const double specular = 0.5;

  /// Specular line on the lit edge and the dimmer bounce opposite it.
  static const double rimAlpha = 0.85;
  static const double bounceAlpha = 0.16;

  /// Soft dark line where the bevel meets the flat body.
  static const double depthShade = 0.1;

  static const double rimWidth = 6;
  static const Offset light = Offset(-0.4, -1);
  static const double tintFeather = 44;

  static Color navTint(ColorScheme cs) =>
      cs.surfaceContainerHigh.withValues(alpha: 0.2);

  static Color panelTint(ColorScheme cs) => cs.surface.withValues(alpha: 0.24);
}

/// Per-surface tuning. Apple's material behaves differently on small controls
/// and on large panels: a control is mostly rim, so it keeps a tight bevel and
/// a bright specular line, while a panel is mostly body, so it frosts more and
/// lets the lens sit wider and softer.
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
}
