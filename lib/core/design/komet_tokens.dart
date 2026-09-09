import 'package:flutter/material.dart';

class KometTokens {
  KometTokens(ColorScheme colors) : _colors = colors;

  final ColorScheme _colors;

  static KometTokens of(BuildContext context) =>
      KometTokens(Theme.of(context).colorScheme);

  Color get canvas => _colors.surface;
  Color get navigation => _colors.surfaceContainerLow;
  Color get content => _colors.surface;
  Color get raised => _colors.surfaceContainerLow;
  Color get overlay => _colors.surfaceContainerHigh;
  Color get primary => _colors.onSurface;
  Color get secondary => _colors.onSurfaceVariant;
  Color get muted => _colors.onSurfaceVariant;
  Color get danger => _colors.error;
  Color get link => _colors.primary;
  Color get divider => _colors.outlineVariant;
  Color get focused => _colors.primary;
  Color get selected => _colors.secondaryContainer;
  Color get onSelected => _colors.onSecondaryContainer;
  Color get active => _colors.primaryContainer;
  Color get onActive => _colors.onPrimaryContainer;
  Color get hover => _colors.surfaceContainerHigh;
  Color get pressed => _colors.surfaceContainerHighest;
  Color get disabled => _colors.onSurface.withValues(alpha: 0.38);

  static const double compact = 8;
  static const double control = 12;
  static const double card = 14;
  static const double dialog = 16;
  static const double mobileSheet = 24;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;
  static const cardRadius = BorderRadius.all(Radius.circular(card));
  static const controlRadius = BorderRadius.all(Radius.circular(control));

  static Duration motion(BuildContext context, int milliseconds) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}
