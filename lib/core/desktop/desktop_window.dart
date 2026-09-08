import 'dart:io';
import 'dart:ui' show Brightness, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Single source of truth for Windows window chrome.
class DesktopWindow {
  DesktopWindow._();

  static const defaultSize = Size(1280, 720);
  static const minSize = Size(720, 560);
  static const _hideOnCloseKey = 'desktop_hide_on_close';
  static const _channelName = 'ru.komet/desktop_window';

  static final hideOnClose = ValueNotifier<bool>(true);
  static const _channel = MethodChannel(_channelName);

  static bool get isSupported {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  static Future<void> load() async {
    if (!isSupported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      hideOnClose.value = prefs.getBool(_hideOnCloseKey) ?? true;
    } catch (_) {}
  }

  static Future<void> setHideOnClose(bool value) async {
    hideOnClose.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hideOnCloseKey, value);
    } catch (_) {}
  }

  static Future<void> syncTitleBar(Brightness brightness) async {
    if (!isSupported) return;
    try {
      await windowManager.setBrightness(brightness);
    } catch (_) {}
  }

  static Future<void> flashTaskbar() async {
    if (!isSupported) return;
    try {
      final focused = await windowManager.isFocused();
      if (focused) return;
    } catch (_) {}
    try {
      await _channel.invokeMethod<void>('flashTaskbar');
    } catch (_) {}
  }

  static Future<void> stopFlash() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('stopFlash');
    } catch (_) {}
  }
}
