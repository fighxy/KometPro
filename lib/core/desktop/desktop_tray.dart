import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/logger.dart';

class DesktopTray with WindowListener, TrayListener {
  DesktopTray._();
  static final DesktopTray instance = DesktopTray._();

  static bool get isSupported {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  bool _started = false;
  bool _quitting = false;

  Future<void> init() async {
    if (_started || !isSupported) return;
    _started = true;
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await windowManager.setMinimumSize(const Size(420, 520));
    windowManager.addListener(this);
    trayManager.addListener(this);
    try {
      await trayManager.setIcon(_iconPath());
      await trayManager.setToolTip('Komet');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: 'Open Komet'),
            MenuItem.separator(),
            MenuItem(key: 'quit', label: 'Quit'),
          ],
        ),
      );
    } catch (e) {
      logger.w('DesktopTray: иконка трея не встала: $e');
    }
  }

  String _iconPath() {
    if (Platform.isWindows) return 'windows/runner/resources/app_icon.ico';
    return 'assets/komet_icon.png';
  }

  Future<void> reveal() async {
    if (!isSupported) return;
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    if (!isSupported || _quitting) return;
    _quitting = true;
    try {
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (_quitting) return;
    unawaited(windowManager.hide());
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(reveal());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem item) {
    if (item.key == 'quit') {
      unawaited(quit());
      return;
    }
    unawaited(reveal());
  }
}
