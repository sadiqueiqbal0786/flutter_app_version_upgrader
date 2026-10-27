import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// In-memory platform used by the Dart unit tests.
class FakePlatform extends FlutterAppVersionUpgraderPlatform
    with MockPlatformInterfaceMixin {
  FakePlatform({
    this.appInfo = const AppInfo(
      packageName: 'com.example.app',
      versionName: '2.4.1',
      buildNumber: 241,
      platform: 'android',
    ),
  });

  AppInfo appInfo;
  final Map<String, String> store = {};
  final List<String> opened = [];
  bool failCacheReads = false;
  bool failCacheWrites = false;
  bool failAppInfo = false;

  @override
  Future<AppInfo> getAppInfo() async {
    if (failAppInfo) throw StateError('no app info');
    return appInfo;
  }

  @override
  Future<String?> readCache(String key) async {
    if (failCacheReads) throw StateError('read failed');
    return store[key];
  }

  @override
  Future<void> writeCache(String key, String value) async {
    if (failCacheWrites) throw StateError('write failed');
    store[key] = value;
  }

  @override
  Future<void> clearCache(String key) async {
    store.remove(key);
  }

  @override
  Future<bool> openStore({
    String? url,
    String? packageName,
    String? appStoreId,
  }) async {
    opened.add(url ?? 'store:$packageName:$appStoreId');
    return true;
  }
}
