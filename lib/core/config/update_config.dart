abstract final class UpdateConfig {
  static const String baseUrl = String.fromEnvironment(
    'KOMET_UPDATE_BASE_URL',
    defaultValue: 'https://github.com/fighxy/KometPro/releases/latest/download',
  );

  static bool get isConfigured => _normalizedBase.isNotEmpty;

  static Uri get manifestUri => Uri.parse(
    '$_normalizedBase/latest.json',
  ).replace(queryParameters: {'t': _cacheBuster});

  static const String _githubDownloadSuffix = '/releases/latest/download';

  static String get downloadsPage {
    final base = _normalizedBase;
    if (base.endsWith(_githubDownloadSuffix)) {
      return base.substring(0, base.length - '/download'.length);
    }
    return base;
  }

  static String get _normalizedBase {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static String get _cacheBuster =>
      (DateTime.now().millisecondsSinceEpoch ~/ 60000).toString();
}
