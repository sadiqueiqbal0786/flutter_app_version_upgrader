import 'package:meta/meta.dart';

import 'semantic_version.dart';
import 'version_info.dart';

/// Identity and version details of the installed application, read from the
/// native platform (`PackageManager` on Android, the main `Bundle` on iOS).
@immutable
class AppInfo {
  /// Creates an [AppInfo].
  const AppInfo({
    required this.packageName,
    required this.versionName,
    required this.buildNumber,
    required this.platform,
  });

  /// Parses the map returned by the native `getAppInfo` method.
  factory AppInfo.fromMap(Map<Object?, Object?> map) {
    final build = map['buildNumber'];
    return AppInfo(
      packageName: map['packageName'] as String? ?? '',
      versionName: map['versionName'] as String? ?? '',
      buildNumber: build is int ? build : int.tryParse('${build ?? ''}'),
      platform: map['platform'] as String? ?? '',
    );
  }

  /// The application id / bundle identifier.
  final String packageName;

  /// The marketing version (`versionName` / `CFBundleShortVersionString`).
  final String versionName;

  /// The build number (`versionCode` / `CFBundleVersion`), if numeric.
  final int? buildNumber;

  /// `android` or `ios`.
  final String platform;

  /// The installed version as a [VersionInfo].
  ///
  /// Throws [VersionFormatException] if [versionName] is not parsable.
  VersionInfo toVersionInfo() =>
      VersionInfo(SemanticVersion.parse(versionName), build: buildNumber);

  @override
  String toString() =>
      'AppInfo($packageName $versionName+${buildNumber ?? '?'} on $platform)';
}
