import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_info.dart';
import 'flutter_app_version_upgrader_platform_interface.dart';

/// Method-channel implementation of [FlutterAppVersionUpgraderPlatform].
class MethodChannelFlutterAppVersionUpgrader
    extends FlutterAppVersionUpgraderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_app_version_upgrader');

  @override
  Future<AppInfo> getAppInfo() async {
    final map = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getAppInfo',
    );
    if (map == null) {
      throw PlatformException(
        code: 'no_app_info',
        message: 'The platform returned no application info.',
      );
    }
    return AppInfo.fromMap(map);
  }

  @override
  Future<String?> readCache(String key) =>
      methodChannel.invokeMethod<String>('readCache', {'key': key});

  @override
  Future<void> writeCache(String key, String value) => methodChannel
      .invokeMethod<void>('writeCache', {'key': key, 'value': value});

  @override
  Future<void> clearCache(String key) =>
      methodChannel.invokeMethod<void>('clearCache', {'key': key});

  @override
  Future<bool> openStore({
    String? url,
    String? packageName,
    String? appStoreId,
  }) async {
    final launched = await methodChannel.invokeMethod<bool>('openStore', {
      'url': ?url,
      'packageName': ?packageName,
      'appStoreId': ?appStoreId,
    });
    return launched ?? false;
  }
}
