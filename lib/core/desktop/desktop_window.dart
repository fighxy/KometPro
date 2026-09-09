import 'dart:async';
import 'dart:io';
import 'dart:ui' show Brightness, Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Single source of truth for Windows window chrome.
class DesktopWindow {
  DesktopWindow._();

  static const defaultSize = Size(1280, 720);
  static const minSize = Size(480, 400);
  static const _hideOnCloseKey = 'desktop_hide_on_close';
  static const _micaKey = 'desktop_mica';
  static const _autoStartKey = 'desktop_auto_start';
  static const _channelName = 'ru.komet/desktop_window';

  static final hideOnClose = ValueNotifier<bool>(true);
  static final micaEnabled = ValueNotifier<bool>(false);
  static final autoStart = ValueNotifier<bool>(false);
  static const _channel = MethodChannel(_channelName);
  static final openChatId = ValueNotifier<int?>(null);
  static void Function(String action)? onTrayAction;
  static bool _taskbarSkipped = false;

  static bool get isSupported {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  static Future<void> load() async {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openChat') {
        final id = call.arguments;
        final chatId = id is int ? id : int.tryParse(id?.toString() ?? '');
        if (chatId != null && chatId != 0) openChatId.value = chatId;
      }
      if (call.method == 'trayAction') {
        final action = call.arguments?.toString();
        if (action != null && action.isNotEmpty) {
          onTrayAction?.call(action);
        }
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      hideOnClose.value = prefs.getBool(_hideOnCloseKey) ?? true;
      micaEnabled.value = prefs.getBool(_micaKey) ?? false;
    } catch (_) {}
    try {
      final pending = await _channel.invokeMethod<int>('takeLaunchChat');
      if (pending != null && pending != 0) openChatId.value = pending;
    } catch (_) {}
    try {
      final enabled = await _channel.invokeMethod<bool>('getAutoStart');
      if (enabled != null) autoStart.value = enabled;
    } catch (_) {}
    if (micaEnabled.value) {
      unawaited(applyMica(micaEnabled.value));
    }
  }

  static Future<void> setJumpList(List<({int id, String title})> chats) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setJumpList', {
        'chats': [
          for (final chat in chats.take(8))
            {'id': chat.id, 'title': chat.title},
        ],
      });
    } catch (_) {}
  }

  static Future<void> setHideOnClose(bool value) async {
    hideOnClose.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hideOnCloseKey, value);
    } catch (_) {}
  }

  static Future<void> setMica(bool value) async {
    micaEnabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_micaKey, value);
    } catch (_) {}
    await applyMica(value);
  }

  static Future<void> applyMica(bool value) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setMica', value);
    } catch (_) {}
    try {
      await windowManager.setHasShadow(true);
    } catch (_) {}
  }

  static Future<void> setAutoStart(bool value) async {
    autoStart.value = value;
    try {
      await _channel.invokeMethod<void>('setAutoStart', value);
    } catch (_) {
      autoStart.value = !value;
    }
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

  static bool isPlausibleOffset(Offset? offset) {
    if (offset == null) return false;
    return offset.dx > -2000 &&
        offset.dy > -2000 &&
        offset.dx < 8000 &&
        offset.dy < 8000;
  }

  static Future<void> forceShow() async {
    if (!isSupported) return;
    if (_taskbarSkipped) {
      try {
        await windowManager.setSkipTaskbar(false);
      } catch (_) {}
      _taskbarSkipped = false;
    }
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
    } catch (_) {}
    try {
      await windowManager.show();
    } catch (_) {}
    try {
      await _channel.invokeMethod<void>('forceForeground');
    } catch (_) {
      try {
        await windowManager.focus();
      } catch (_) {}
    }
    try {
      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      if (size.width < 200 ||
          size.height < 160 ||
          !isPlausibleOffset(pos)) {
        await windowManager.setSize(defaultSize);
        await windowManager.center();
      }
    } catch (_) {}
    await kickCompositor();
  }

  static Future<void> skipTaskbar() async {
    if (!isSupported) return;
    _taskbarSkipped = true;
    try {
      await windowManager.setSkipTaskbar(true);
    } catch (_) {}
  }

  static Future<void> kickCompositor() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('kickCompositor');
    } catch (_) {}
  }

  static Future<void> addNativeTray({
    required String tip,
    required String show,
    required String hide,
    required String quit,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('nativeTray', {
        'tip': tip,
        'show': show,
        'hide': hide,
        'quit': quit,
      });
    } catch (_) {}
  }

  static Future<void> setTrayTip(String tip) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setTrayTip', tip);
    } catch (_) {}
  }

  static Future<void> removeNativeTray() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('removeNativeTray');
    } catch (_) {}
  }
}
