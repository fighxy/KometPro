import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Edge-to-edge + contrast-safe bars on Android 10+.
void syncAndroidSystemUi(Brightness brightness) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final lightIcons = brightness == Brightness.light;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: lightIcons ? Brightness.dark : Brightness.light,
      statusBarBrightness: lightIcons ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          lightIcons ? Brightness.dark : Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}
