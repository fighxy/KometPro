import 'dart:async';
import 'dart:io';
import 'dart:ui' show Offset, PlatformDispatcher, Size;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/logger.dart';

class DesktopTray with WindowListener, TrayListener {
  DesktopTray._();
  static final DesktopTray instance = DesktopTray._();

  static const _widthKey = 'desktop_window_width';
  static const _heightKey = 'desktop_window_height';
  static const _xKey = 'desktop_window_x';
  static const _yKey = 'desktop_window_y';
  static const _assetIco = 'assets/tray/komet.ico';
  static const _assetPng = 'assets/komet_icon.png';

  static bool get isSupported {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  bool _started = false;
  bool _quitting = false;
  bool _hidden = false;
  int _unread = 0;

  Future<void> setUnread(int count) async {
    if (!isSupported || !_started) return;
    final next = count < 0 ? 0 : count;
    if (next == _unread) return;
    _unread = next;
    try {
      final tip = next == 0
          ? 'Komet'
          : (PlatformDispatcher.instance.locale.languageCode == 'ru'
                ? 'Komet — $next непрочитанных'
                : 'Komet — $next unread');
      await trayManager.setToolTip(tip);
      await _rebuildMenu();
    } catch (e) {
      logger.w('DesktopTray: badge failed: $e');
    }
  }

  Future<void> init() async {
    if (_started || !isSupported) return;
    _started = true;
    await windowManager.ensureInitialized();
    final bounds = await _loadBounds();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: bounds.size,
        minimumSize: const Size(420, 520),
        center: bounds.offset == null,
        title: 'Komet',
      ),
      () async {
        if (bounds.offset != null) {
          await windowManager.setPosition(bounds.offset!);
        }
        await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();
      },
    );
    windowManager.addListener(this);
    trayManager.addListener(this);
    try {
      final icon = await _resolveIcon();
      await trayManager.setIcon(icon);
      await trayManager.setToolTip('Komet');
      await _rebuildMenu();
    } catch (e) {
      logger.w('DesktopTray: иконка трея не встала: $e');
    }
  }

  Future<void> _rebuildMenu() async {
    final ru = PlatformDispatcher.instance.locale.languageCode == 'ru';
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show',
            label: _unread > 0
                ? (ru
                      ? 'Открыть Komet ($_unread)'
                      : 'Open Komet ($_unread)')
                : (ru ? 'Открыть Komet' : 'Open Komet'),
          ),
          MenuItem(key: 'hide', label: ru ? 'Скрыть' : 'Hide'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: ru ? 'Выйти' : 'Quit'),
        ],
      ),
    );
  }

  Future<String> _resolveIcon() async {
    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final candidates = <String>[
        '$exeDir${Platform.pathSeparator}app_icon.ico',
        '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}$_assetIco',
        '${Directory.current.path}${Platform.pathSeparator}windows${Platform.pathSeparator}runner${Platform.pathSeparator}resources${Platform.pathSeparator}app_icon.ico',
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) return path;
      }
      return _extractAsset(_assetIco, 'komet_tray.ico');
    }
    if (Platform.isLinux) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final bundled =
          '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}$_assetPng';
      if (File(bundled).existsSync()) return bundled;
    }
    return _assetPng;
  }

  Future<String> _extractAsset(String asset, String fileName) async {
    final data = await rootBundle.load(asset);
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }

  Future<({Size size, Offset? offset})> _loadBounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final w = prefs.getDouble(_widthKey);
      final h = prefs.getDouble(_heightKey);
      final x = prefs.getDouble(_xKey);
      final y = prefs.getDouble(_yKey);
      final size = Size(
        (w ?? 1100).clamp(420, 4000),
        (h ?? 720).clamp(520, 3000),
      );
      if (x == null || y == null) return (size: size, offset: null);
      return (size: size, offset: Offset(x, y));
    } catch (_) {
      return (size: const Size(1100, 720), offset: null);
    }
  }

  Future<void> _persistBounds() async {
    try {
      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_widthKey, size.width);
      await prefs.setDouble(_heightKey, size.height);
      await prefs.setDouble(_xKey, pos.dx);
      await prefs.setDouble(_yKey, pos.dy);
    } catch (_) {}
  }

  Future<void> reveal() async {
    if (!isSupported) return;
    _hidden = false;
    try {
      await windowManager.setSkipTaskbar(false);
    } catch (_) {}
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideToTray() async {
    if (!isSupported) return;
    _hidden = true;
    await _persistBounds();
    await windowManager.hide();
    try {
      await windowManager.setSkipTaskbar(true);
    } catch (_) {}
  }

  Future<void> quit() async {
    if (!isSupported || _quitting) return;
    _quitting = true;
    await _persistBounds();
    try {
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (_quitting) return;
    unawaited(hideToTray());
  }

  @override
  void onWindowMoved() => unawaited(_persistBounds());

  @override
  void onWindowResized() => unawaited(_persistBounds());

  @override
  void onTrayIconMouseDown() {
    if (_hidden) {
      unawaited(reveal());
    } else if (Platform.isWindows) {
      unawaited(hideToTray());
    } else {
      unawaited(reveal());
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem item) {
    switch (item.key) {
      case 'quit':
        unawaited(quit());
      case 'hide':
        unawaited(hideToTray());
      default:
        unawaited(reveal());
    }
  }
}
