import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How strong the glass material is allowed to be.
///
/// Two inputs feed it. The system side is a boolean: iOS and macOS expose
/// "Reduce Transparency", Android reports whether the compositor runs
/// cross-window blur at all, and when either says no, glass drops to a plain
/// surface. No platform exposes a blur *amount*, so the amount itself is an
/// in-app scale the user sets.
class GlassIntensity {
  GlassIntensity._();

  static const _channel = MethodChannel('komet/system_transparency');
  static const prefKey = 'glass_intensity';

  static const double min = 0.5;
  static const double max = 1.5;
  static const double step = 0.1;
  static const double def = 1.0;

  /// User-set multiplier for blur and lens size.
  static final ValueNotifier<double> scale = ValueNotifier<double>(def);

  /// False when the platform asks for reduced transparency, or cannot blur.
  static final ValueNotifier<bool> systemAllowsBlur = ValueNotifier<bool>(true);

  static double clamp(double value) {
    final snapped = (value / step).round() * step;
    return snapped.clamp(min, max);
  }

  static int get percent => (scale.value * 100).round();

  /// Multiplier for blur radii and frost size.
  static double get factor => scale.value;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      scale.value = clamp(prefs.getDouble(prefKey) ?? def);
    } catch (_) {}
    await refreshSystem();
  }

  static Future<void> save(double value) async {
    final clamped = clamp(value);
    scale.value = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(prefKey, clamped);
    } catch (_) {}
  }

  /// Asks the platform whether translucency is wanted. Platforms without the
  /// setting answer nothing and keep glass enabled.
  static Future<void> refreshSystem() async {
    if (kIsWeb) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.android:
        break;
      default:
        return;
    }
    try {
      final allowed = await _channel.invokeMethod<bool>('allowsBlur');
      if (allowed != null) systemAllowsBlur.value = allowed;
    } catch (_) {}
  }
}
