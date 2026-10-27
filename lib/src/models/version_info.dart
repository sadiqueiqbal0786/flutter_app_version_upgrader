import 'package:meta/meta.dart';

import 'semantic_version.dart';

/// A version string paired with an optional platform build number.
///
/// Ordering compares the semantic [version] first. When the versions are
/// equal and both sides carry a [build] number, the build numbers decide.
/// This mirrors how the stores treat versions: Google Play keys releases on
/// `versionCode`, the App Store on `CFBundleVersion`, and both allow the
/// marketing version to stay the same across several builds.
@immutable
class VersionInfo implements Comparable<VersionInfo> {
  /// Creates a [VersionInfo].
  const VersionInfo(this.version, {this.build});

  /// Parses [version] and wraps it with [build].
  ///
  /// Throws [VersionFormatException] if [version] is malformed.
  factory VersionInfo.parse(String version, {int? build}) =>
      VersionInfo(SemanticVersion.parse(version), build: build);

  /// Parses a `{ "version": "...", "build": 123 }` map.
  ///
  /// Returns `null` when [json] is `null` or has no parsable `version`.
  static VersionInfo? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final version = SemanticVersion.tryParse(json['version'] as String?);
    if (version == null) return null;
    return VersionInfo(version, build: _toInt(json['build']));
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  /// The semantic version.
  final SemanticVersion version;

  /// The platform build number (`versionCode` / `CFBundleVersion`), if known.
  final int? build;

  /// Serialises to the wire format used by the version API.
  Map<String, dynamic> toJson() => {
        'version': version.toString(),
        if (build != null) 'build': build,
      };

  @override
  int compareTo(VersionInfo other) {
    final byVersion = version.compareTo(other.version);
    if (byVersion != 0) return byVersion;
    final a = build;
    final b = other.build;
    if (a == null || b == null) return 0;
    return a.compareTo(b);
  }

  /// `this < other`.
  bool operator <(VersionInfo other) => compareTo(other) < 0;

  /// `this >= other`.
  bool operator >=(VersionInfo other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) => other is VersionInfo && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(version, build);

  @override
  String toString() => build == null ? '$version' : '$version ($build)';
}
