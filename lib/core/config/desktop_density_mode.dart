import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

enum DesktopDensityMode { comfortable, compact }

class AppDesktopDensity {
  static final _setting = PersistedEnum<DesktopDensityMode>(
    prefKey: 'desktop_density_mode',
    defaultValue: DesktopDensityMode.comfortable,
    encode: (value) => value.name,
    decode: (value) => enumFromName(
      DesktopDensityMode.values,
      value,
      DesktopDensityMode.comfortable,
    ),
  );

  static ValueNotifier<DesktopDensityMode> get current => _setting.current;
  static Future<DesktopDensityMode> load() => _setting.load();
  static Future<void> save(DesktopDensityMode value) => _setting.save(value);
}
