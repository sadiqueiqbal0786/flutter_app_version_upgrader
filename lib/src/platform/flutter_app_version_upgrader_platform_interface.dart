import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../models/app_info.dart';
import 'flutter_app_version_upgrader_method_channel.dart';

/// The interface that platform implementations of this plugin must extend.
///
/// The native layer deliberately stays small. It provides only what Dart
/// cannot do by itself: read the installed version, persist a small cache,
/// and open the platform's store page.
abstract class FlutterAppVersionUpgraderPlatform extends PlatformInterface {
  /// Constructs a [FlutterAppVersionUpgraderPlatform].
  FlutterAppVersionUpgraderPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterAppVersionUpgraderPlatform _instance =
      MethodChannelFlutterAppVersionUpgrader();

  /// The default instance of [FlutterAppVersionUpgraderPlatform] to use.
  static FlutterAppVersionUpgraderPlatform get instance => _instance;

  /// Platform-specific implementations register themselves here.
  static set instance(FlutterAppVersionUpgraderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Reads the installed application's identity and version.
  Future<AppInfo> getAppInfo() {
    throw UnimplementedError('getAppInfo() has not been implemented.');
  }

  /// Reads a cached string stored under [key], or `null`.
  Future<String?> readCache(String key) {
    throw UnimplementedError('readCache() has not been implemented.');
  }

  /// Persists [value] under [key].
  Future<void> writeCache(String key, String value) {
    throw UnimplementedError('writeCache() has not been implemented.');
  }

  /// Removes the value stored under [key].
  Future<void> clearCache(String key) {
    throw UnimplementedError('clearCache() has not been implemented.');
  }

  /// Opens the app's store listing.
  ///
  /// When [url] is provided it is opened as-is (this is the `update.url` the
  /// backend returns). Otherwise the platform falls back to its own store
  /// deep link using [packageName] (Android) or [appStoreId] (iOS).
  ///
  /// Returns `true` if something was launched.
  Future<bool> openStore({String? url, String? packageName, String? appStoreId}) {
    throw UnimplementedError('openStore() has not been implemented.');
  }
}
