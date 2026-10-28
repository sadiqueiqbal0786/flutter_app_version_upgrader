import 'package:flutter/foundation.dart';

import '../models/app_info.dart';
import 'flutter_app_version_upgrader_platform_interface.dart';

/// Platform implementation used where no native code exists (web, macOS,
/// Windows, Linux) so that the plugin degrades gracefully instead of
/// throwing [MissingPluginException].
///
/// * [getAppInfo] throws [UnsupportedError] unless an [appInfo] was supplied,
///   which `VersionManager` turns into a fail-open `checkFailed` result.
///   Supplying `currentVersionOverride` and `appId` in the config lets the
///   check still run against the API on these platforms.
/// * The cache lives in memory for the lifetime of the isolate.
/// * [openStore] does nothing and returns `false`.
class InMemoryFlutterAppVersionUpgraderPlatform
    extends FlutterAppVersionUpgraderPlatform {
  /// Creates an in-memory platform, optionally with a fixed [appInfo].
  InMemoryFlutterAppVersionUpgraderPlatform({this.appInfo});

  /// The application info to report, if any.
  final AppInfo? appInfo;

  final Map<String, String> _store = {};

  /// Name of the host platform, for diagnostics.
  static String get hostPlatformName =>
      kIsWeb ? 'web' : defaultTargetPlatform.name;

  @override
  Future<AppInfo> getAppInfo() async {
    final info = appInfo;
    if (info != null) return info;
    throw UnsupportedError(
      'flutter_app_version_upgrader has no native implementation on '
      '$hostPlatformName. Provide appId and currentVersionOverride in '
      'VersionManagerConfig to run checks here.',
    );
  }

  @override
  Future<String?> readCache(String key) async => _store[key];

  @override
  Future<void> writeCache(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> clearCache(String key) async {
    _store.remove(key);
  }

  @override
  Future<bool> openStore({
    String? url,
    String? packageName,
    String? appStoreId,
  }) async =>
      false;
}
