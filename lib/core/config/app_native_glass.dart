import 'package:flutter/foundation.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import 'app_visual_style.dart';
import 'glass_intensity.dart';
import 'persisted_setting.dart';

class AppNativeGlass {
  static final _setting = PersistedSetting<bool>(
    prefKey: 'native_liquid_glass',
    defaultValue: true,
    read: (prefs, key) => prefs.getBool(key),
    write: (prefs, key, value) async {
      await prefs.setBool(key, value);
    },
  );

  static bool get supported => NativeLiquidGlassUtils.supportsLiquidGlass;

  static bool get enabled =>
      supported &&
      current.value &&
      AppVisualStyle.current.value == VisualStyle.liquidGlass &&
      GlassIntensity.systemAllowsBlur.value;

  static ValueNotifier<bool> get current => _setting.current;
  static Future<bool> load() => _setting.load();
  static Future<void> save(bool value) => _setting.save(value);

  static final changes = Listenable.merge([
    current,
    AppVisualStyle.current,
    GlassIntensity.systemAllowsBlur,
  ]);
}
