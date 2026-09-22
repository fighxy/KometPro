import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_liquid_glass.dart';
import '../config/app_visual_style.dart';

class IosChrome {
  IosChrome._();

  static bool get isCupertino =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool get isPhone =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static VisualStyle get preferredStyle =>
      isPhone ? VisualStyle.liquidGlass : VisualStyle.materialYou;

  static const double navInset = 16;
  static const double navLift = 10;
  static const double expandedHeight = capsuleSide + 2 * _expandedPadding;
  static const double compactHeight = 52;
  static const double outerRadius = expandedHeight / 2;
  static const double innerRadius = expandedHeight * 0.382;
  static const double sheetRadius = 28;
  static const double collapseDistance = 56;
  static const double iconsOnlyAt = 0.55;
  static const double minimumTarget = 44;

  static const double _expandedPadding = 6;
  static const double _compactPadding = 4;

  static double navPaddingAt(double collapse) =>
      lerpDouble(_expandedPadding, _compactPadding, collapse.clamp(0.0, 1.0))!;

  /// Capsules in the chat header and the composer share one size and one
  /// shadow depth; both read them from here so they cannot drift apart.
  static const double capsuleSide = 46;
  static const double capsuleDepth = 4;

  static const double listTitleSize = 17;
  static const FontWeight listTitleWeight = FontWeight.w600;
  static const double listPreviewSize = 15;
  static const FontWeight listPreviewWeight = FontWeight.w400;
  static const double listTimeSize = 14;
  static const FontWeight listTimeWeight = FontWeight.w400;
  static const double fieldTextSize = 16;
  static const FontWeight fieldTextWeight = FontWeight.w500;
  static const double bubbleBodySize = 17;
  static const FontWeight bubbleBodyWeight = FontWeight.w400;
  static const double bubbleMetaSize = 12;
  static const FontWeight bubbleMetaWeight = FontWeight.w400;

  static double heightAt(double collapse) =>
      lerpDouble(expandedHeight, compactHeight, collapse.clamp(0.0, 1.0))!;

  static bool iconsOnly(double collapse) => collapse >= iconsOnlyAt;

  static double navBottom(double safeBottom) => safeBottom + navLift;

  static double contentClearance(double safeBottom, {double collapse = 0}) =>
      navBottom(safeBottom) + heightAt(collapse) + 10;

  static double fabClearance(double safeBottom, {double collapse = 0}) =>
      contentClearance(safeBottom, collapse: collapse);

  static double collapseFromOffset(double pixels) =>
      (pixels / collapseDistance).clamp(0.0, 1.0);

  static double applyScrollDelta(double current, double delta) {
    if (delta > 0) {
      return (current + delta / collapseDistance).clamp(0.0, 1.0);
    }
    if (delta < 0) {
      return (current + delta / (collapseDistance * 0.65)).clamp(0.0, 1.0);
    }
    return current.clamp(0.0, 1.0);
  }

  static Color edgeTint(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    return Color.lerp(
      cs.outlineVariant,
      dark ? Colors.black : cs.onSurface,
      dark ? 0.35 : 0.18,
    )!.withValues(alpha: dark ? 0.55 : 0.28);
  }

  static Color navTint(ColorScheme cs) =>
      AppLiquidGlass.navTint(cs).withValues(alpha: isPhone ? 0.32 : 0.2);

  static Color panelTint(ColorScheme cs) =>
      AppLiquidGlass.panelTint(cs).withValues(alpha: isPhone ? 0.36 : 0.24);
}
