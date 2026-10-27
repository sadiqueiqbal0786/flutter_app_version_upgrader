import '../platform/flutter_app_version_upgrader_platform_interface.dart';

/// Opens the platform store page so the user can install the update.
class StoreLauncher {
  /// Creates a [StoreLauncher].
  StoreLauncher(this._platform);

  final FlutterAppVersionUpgraderPlatform _platform;

  /// Opens [url] when given, otherwise the store listing derived from
  /// [packageName] (Android) or [appStoreId] (iOS).
  ///
  /// Returns `true` if a store or browser was launched.
  Future<bool> open({String? url, String? packageName, String? appStoreId}) =>
      _platform.openStore(
        url: url,
        packageName: packageName,
        appStoreId: appStoreId,
      );
}
