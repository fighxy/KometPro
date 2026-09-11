import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/logger.dart';
import 'desktop_window.dart';

class DesktopTray with WindowListener, TrayListener {
  DesktopTray._();
  static final DesktopTray instance = DesktopTray._();

  static const _widthKey = 'desktop_window_width';
  static const _heightKey = 'desktop_window_height';
  static const _xKey = 'desktop_window_x';
  static const _yKey = 'desktop_window_y';
  static const _assetIco = 'assets/tray/komet.ico';
  static const _assetPng = 'assets/komet_icon.png';

  static bool get isSupported => DesktopWindow.isSupported;

  bool _started = false;
  bool _quitting = false;
  bool _hidden = false;
  int _unread = 0;

  Future<void> setUnread(int count) async {
    if (!isSupported || !_started) return;
    final next = count < 0 ? 0 : count;
    final grew = next > _unread;
    if (next == _unread) return;
    _unread = next;
    try {
      final tip = next == 0
          ? 'Komet'
          : (ui.PlatformDispatcher.instance.locale.languageCode == 'ru'
                ? 'Komet — $next непрочитанных'
                : 'Komet — $next unread');
      if (Platform.isWindows) {
        await DesktopWindow.addNativeTray(
          tip: tip,
          show: next > 0
              ? (ui.PlatformDispatcher.instance.locale.languageCode == 'ru'
                    ? 'Открыть Komet ($next)'
                    : 'Open Komet ($next)')
              : (ui.PlatformDispatcher.instance.locale.languageCode == 'ru'
                    ? 'Открыть Komet'
                    : 'Open Komet'),
          hide: ui.PlatformDispatcher.instance.locale.languageCode == 'ru'
              ? 'Скрыть'
              : 'Hide',
          quit: ui.PlatformDispatcher.instance.locale.languageCode == 'ru'
              ? 'Выйти'
              : 'Quit',
        );
      } else {
        await trayManager.setToolTip(tip);
        await _rebuildMenu();
      }
    } catch (e) {
      logger.w('DesktopTray: badge failed: $e');
    }
    if (grew && !_hidden) {
      unawaited(DesktopWindow.flashTaskbar());
    } else if (next == 0) {
      unawaited(DesktopWindow.stopFlash());
    }
    unawaited(_refreshIcon());
  }

  Future<void> init({bool startHidden = false}) async {
    if (_started || !isSupported) return;
    _started = true;
    await DesktopWindow.load();
    await windowManager.ensureInitialized();
    final bounds = await _loadBounds();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: bounds.size,
        minimumSize: DesktopWindow.minSize,
        center: !DesktopWindow.isPlausibleOffset(bounds.offset),
        title: 'Komet',
      ),
      () async {
        await windowManager.setPreventClose(true);
        if (startHidden) {
          _hidden = true;
          await windowManager.hide();
          await DesktopWindow.skipTaskbar();
        } else {
          await DesktopWindow.forceShow();
        }
        if (!startHidden && DesktopWindow.isPlausibleOffset(bounds.offset)) {
          try {
            await windowManager.setPosition(bounds.offset!);
          } catch (_) {}
        }
      },
    );
    windowManager.addListener(this);
    DesktopWindow.onTrayAction = _onNativeTrayAction;
    try {
      if (Platform.isWindows) {
        await _addNativeTray();
      } else {
        trayManager.addListener(this);
        final icon = await _resolveIcon();
        await trayManager.setIcon(icon);
        await trayManager.setToolTip('Komet');
        await _rebuildMenu();
      }
    } catch (e) {
      logger.w('DesktopTray: иконка трея не встала: $e');
      if (_hidden) await reveal();
    }
  }

  Future<void> _addNativeTray() async {
    final ru = ui.PlatformDispatcher.instance.locale.languageCode == 'ru';
    await DesktopWindow.addNativeTray(
      tip: _unread == 0
          ? 'Komet'
          : (ru
                ? 'Komet — $_unread непрочитанных'
                : 'Komet — $_unread unread'),
      show: _unread > 0
          ? (ru ? 'Открыть Komet ($_unread)' : 'Open Komet ($_unread)')
          : (ru ? 'Открыть Komet' : 'Open Komet'),
      hide: ru ? 'Скрыть' : 'Hide',
      quit: ru ? 'Выйти' : 'Quit',
    );
  }

  void _onNativeTrayAction(String action) {
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      switch (action) {
        case 'quit':
          unawaited(quit());
        case 'hide':
          unawaited(hideToTray());
        default:
          unawaited(reveal());
      }
    });
  }

  Future<void> _rebuildMenu() async {
    final ru = ui.PlatformDispatcher.instance.locale.languageCode == 'ru';
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

  Future<void> _refreshIcon() async {
    if (!isSupported || !_started || Platform.isWindows) return;
    try {
      final icon = _unread > 0 ? await _paintBadgeIcon(_unread) : await _resolveIcon();
      await trayManager.setIcon(icon);
    } catch (e) {
      logger.w('DesktopTray: icon refresh failed: $e');
    }
  }

  Future<String> _paintBadgeIcon(int count) async {
    const dim = 64;
    final data = await rootBundle.load(_assetPng);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: dim,
      targetHeight: dim,
    );
    final frame = await codec.getNextFrame();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(frame.image, Offset.zero, Paint());
    final badge = Paint()..color = const Color(0xFFE53935);
    canvas.drawCircle(const Offset(50, 14), 13, badge);
    canvas.drawCircle(
      const Offset(50, 14),
      13,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final label = count > 9 ? '9+' : '$count';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(50 - tp.width / 2, 14 - tp.height / 2));
    final picture = recorder.endRecording();
    final image = await picture.toImage(dim, dim);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}komet_tray_badge.png');
    await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
    return file.path;
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
        (w ?? DesktopWindow.defaultSize.width).clamp(
          DesktopWindow.minSize.width,
          4000,
        ),
        (h ?? DesktopWindow.defaultSize.height).clamp(
          DesktopWindow.minSize.height,
          3000,
        ),
      );
      if (x == null || y == null) return (size: size, offset: null);
      return (size: size, offset: Offset(x, y));
    } catch (_) {
      return (size: DesktopWindow.defaultSize, offset: null);
    }
  }

  Future<void> _persistBounds() async {
    if (_hidden) return;
    try {
      if (!await windowManager.isVisible()) return;
      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      if (size.width < 200 ||
          size.height < 160 ||
          !DesktopWindow.isPlausibleOffset(pos)) {
        return;
      }
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
    await DesktopWindow.forceShow();
    unawaited(DesktopWindow.stopFlash());
  }

  Future<void> hideToTray() async {
    if (!isSupported) return;
    await _persistBounds();
    _hidden = true;
    await windowManager.hide();
    await DesktopWindow.skipTaskbar();
  }

  Future<void> quit() async {
    if (!isSupported || _quitting) return;
    _quitting = true;
    await _persistBounds();
    try {
      if (Platform.isWindows) {
        await DesktopWindow.removeNativeTray();
      } else {
        await trayManager.destroy();
      }
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (_quitting) return;
    if (DesktopWindow.hideOnClose.value) {
      unawaited(hideToTray());
    } else {
      unawaited(quit());
    }
  }

  @override
  void onWindowMoved() => unawaited(_persistBounds());

  @override
  void onWindowResized() => unawaited(_persistBounds());

  @override
  void onTrayIconMouseDown() {
    unawaited(reveal());
  }

  @override
  void onTrayIconRightMouseDown() {
    if (Platform.isWindows) return;
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem item) {
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      switch (item.key) {
        case 'quit':
          unawaited(quit());
        case 'hide':
          unawaited(hideToTray());
        default:
          unawaited(reveal());
      }
    });
  }
}

