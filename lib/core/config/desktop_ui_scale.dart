import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Extra interface scale on top of OS DPI.
/// Telegram Desktop uses integer percents and multiplies every layout
/// constant defined at 100%. Same idea here: 75–150%, 5% steps.
class DesktopUiScale {
  DesktopUiScale._();

  static const prefKey = 'desktop_ui_scale';
  static const double min = 0.75;
  static const double max = 1.50;
  static const double step = 0.05;
  static const double def = 1.0;

  static final value = ValueNotifier<double>(def);

  static double get current => value.value;

  static int get percent => (current * 100).round();

  static double clamp(double scale) {
    final snapped = (scale / step).round() * step;
    return snapped.clamp(min, max);
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value.value = clamp(prefs.getDouble(prefKey) ?? def);
    } catch (_) {
      value.value = def;
    }
  }

  static Future<void> set(double scale) async {
    final next = clamp(scale);
    if ((next - value.value).abs() < 0.001) return;
    value.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(prefKey, next);
    } catch (_) {}
  }
}
