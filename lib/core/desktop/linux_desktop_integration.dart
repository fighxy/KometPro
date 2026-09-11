import 'dart:io';

abstract final class LinuxDesktopIntegration {
  static const applicationId = 'ru.komet.app';

  static String get launchExecutable {
    final appImage = Platform.environment['APPIMAGE']?.trim();
    if (appImage != null && appImage.isNotEmpty) return appImage;
    return Platform.resolvedExecutable;
  }

  static Future<bool> getAutoStart() async {
    final file = _autoStartFile;
    if (file == null || !await file.exists()) return false;
    if (await file.readAsString() != _autoStartEntry) {
      await file.writeAsString(_autoStartEntry, flush: true);
    }
    return true;
  }

  static Directory? get applicationsDirectory {
    final dataHome = Platform.environment['XDG_DATA_HOME']?.trim();
    if (dataHome != null && dataHome.isNotEmpty) {
      return Directory('$dataHome/applications');
    }
    final home = Platform.environment['HOME']?.trim();
    if (home == null || home.isEmpty) return null;
    return Directory('$home/.local/share/applications');
  }

  static Future<void> setAutoStart(bool enabled) async {
    final file = _autoStartFile;
    if (file == null) {
      throw const FileSystemException('Linux config directory is unavailable');
    }
    if (!enabled) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(_autoStartEntry, flush: true);
  }

  static String quoteDesktopArgument(String value) {
    final escaped = value
        .replaceAll('\\', '\\\\')
        .replaceAll(r'"', r'\"')
        .replaceAll(r'$', r'\$')
        .replaceAll('`', r'\`');
    return '"$escaped"';
  }

  static File? get _autoStartFile {
    final configHome = Platform.environment['XDG_CONFIG_HOME']?.trim();
    if (configHome != null && configHome.isNotEmpty) {
      return File('$configHome/autostart/$applicationId.desktop');
    }
    final home = Platform.environment['HOME']?.trim();
    if (home == null || home.isEmpty) return null;
    return File('$home/.config/autostart/$applicationId.desktop');
  }

  static String get _autoStartEntry =>
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=Komet\n'
      'Exec=${quoteDesktopArgument(launchExecutable)} --hidden\n'
      'Terminal=false\n'
      'X-GNOME-Autostart-enabled=true\n';
}
