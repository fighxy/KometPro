import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../desktop/linux_desktop_integration.dart';
import 'update_checker.dart';

enum UpdateInstallStatus {
  done,
  noAsset,
  downloadFailed,
  corrupted,
  installFailed,
}

class UpdateInstallResult {
  final UpdateInstallStatus status;
  final String? error;
  final String? relaunchPath;

  const UpdateInstallResult(this.status, {this.error, this.relaunchPath});

  bool get ok => status == UpdateInstallStatus.done;
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

abstract class UpdateInstaller {
  static bool get isSupported =>
      Platform.isAndroid ||
      (Platform.isLinux &&
          (Platform.environment['APPIMAGE']?.trim().isNotEmpty ?? false));

  static Future<UpdateInstallResult> downloadAndInstall(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    if (Platform.isLinux) {
      return _downloadAndInstallAppImage(info, onProgress);
    }
    final asset = await resolveApk(info);
    if (asset == null) {
      return const UpdateInstallResult(UpdateInstallStatus.noAsset);
    }

    File file;
    try {
      file = await _download(asset, info.tag, onProgress);
    } on _ChecksumMismatch catch (e) {
      return UpdateInstallResult(
        UpdateInstallStatus.corrupted,
        error: e.toString(),
      );
    } catch (e) {
      return UpdateInstallResult(
        UpdateInstallStatus.downloadFailed,
        error: e.toString(),
      );
    }

    final opened = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (opened.type != ResultType.done) {
      return UpdateInstallResult(
        UpdateInstallStatus.installFailed,
        error: opened.message,
      );
    }
    return const UpdateInstallResult(UpdateInstallStatus.done);
  }

  static Future<UpdateAsset?> resolveApk(AppUpdateInfo info) async {
    if (!Platform.isAndroid || info.assets.isEmpty) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final flavor = packageInfo.packageName == 'ru.oneme.app' ? 'oneme' : 'komet';

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final abis = androidInfo.supportedAbis;

    for (final abi in abis) {
      final asset = info.assetWithSuffix('-$flavor-$abi.apk');
      if (asset != null) return asset;
    }
    return info.assetWithSuffix('-$flavor-universal.apk');
  }

  static Future<UpdateInstallResult> _downloadAndInstallAppImage(
    AppUpdateInfo info,
    void Function(double progress)? onProgress,
  ) async {
    final appImage = Platform.environment['APPIMAGE']?.trim();
    final asset = info.assetWithSuffix('-linux-x86_64.AppImage');
    if (appImage == null || appImage.isEmpty || asset == null) {
      return const UpdateInstallResult(UpdateInstallStatus.noAsset);
    }
    if (asset.sha256.isEmpty) {
      return const UpdateInstallResult(
        UpdateInstallStatus.corrupted,
        error: 'Missing SHA-256 digest',
      );
    }

    final part = File('$appImage.update-$pid.part');
    try {
      await _downloadTo(asset, part, onProgress);
      final chmod = await Process.run('chmod', ['0755', part.path]);
      if (chmod.exitCode != 0) {
        throw FileSystemException('Could not mark update executable', part.path);
      }
      await part.rename(LinuxDesktopIntegration.launchExecutable);
      return UpdateInstallResult(
        UpdateInstallStatus.done,
        relaunchPath: LinuxDesktopIntegration.launchExecutable,
      );
    } on _ChecksumMismatch catch (e) {
      return UpdateInstallResult(
        UpdateInstallStatus.corrupted,
        error: e.toString(),
      );
    } catch (e) {
      return UpdateInstallResult(
        UpdateInstallStatus.installFailed,
        error: e.toString(),
      );
    } finally {
      if (await part.exists()) {
        try {
          await part.delete();
        } catch (_) {}
      }
    }
  }

  static Future<File> _download(
    UpdateAsset asset,
    String tag,
    void Function(double progress)? onProgress,
  ) async {
    final dir = await getTemporaryDirectory();
    final safeTag = tag.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/komet-update-$safeTag.apk');
    final part = File('${file.path}.part');

    await _downloadTo(asset, part, onProgress);
    if (await file.exists()) await file.delete();
    await part.rename(file.path);
    return file;
  }

  static Future<void> _downloadTo(
    UpdateAsset asset,
    File part,
    void Function(double progress)? onProgress,
  ) async {
    await part.parent.create(recursive: true);

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(asset.url));
      request.headers.set(HttpHeaders.userAgentHeader, 'KometUpdateInstaller');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: Uri.parse(asset.url),
        );
      }

      final total = response.contentLength > 0
          ? response.contentLength
          : asset.size;
      var received = 0;
      final digestSink = _DigestSink();
      final hasher = sha256.startChunkedConversion(digestSink);
      final sink = part.openWrite();
      await for (final chunk in response) {
        received += chunk.length;
        hasher.add(chunk);
        sink.add(chunk);
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      }
      await sink.close();
      hasher.close();

      if (asset.size > 0 && received != asset.size) {
        throw _ChecksumMismatch('size ${asset.size}', 'size $received');
      }
      final actual = digestSink.value?.toString() ?? '';
      if (asset.sha256.isNotEmpty && actual != asset.sha256) {
        throw _ChecksumMismatch(asset.sha256, actual);
      }
    } catch (e) {
      if (await part.exists()) {
        try {
          await part.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}

class _ChecksumMismatch implements Exception {
  final String expected;
  final String actual;

  const _ChecksumMismatch(this.expected, this.actual);

  @override
  String toString() => 'Update payload mismatch: expected $expected, got $actual';
}
