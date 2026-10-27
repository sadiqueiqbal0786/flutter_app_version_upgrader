import 'package:meta/meta.dart';

/// Thrown when a version string cannot be parsed.
class VersionFormatException implements Exception {
  /// Creates a [VersionFormatException] for [input].
  const VersionFormatException(this.input, [this.reason]);

  /// The string that failed to parse.
  final String input;

  /// Optional explanation.
  final String? reason;

  @override
  String toString() =>
      'VersionFormatException: "$input"${reason == null ? '' : ' ($reason)'}';
}

/// A parsed semantic version (`major.minor.patch[-preRelease][+build]`).
///
/// Comparison follows the Semantic Versioning 2.0.0 precedence rules:
///
/// * `major`, `minor`, `patch` are compared numerically.
/// * A version with a pre-release tag has *lower* precedence than the same
///   version without one (`2.8.0-beta.2 < 2.8.0`).
/// * Pre-release identifiers are compared left to right; numeric identifiers
///   compare numerically and have lower precedence than alphanumeric ones.
/// * Build metadata is ignored for precedence.
///
/// Lenient parsing is supported for the shapes that commonly appear in store
/// listings and `pubspec.yaml` files: a leading `v`, a missing patch or minor
/// component (`2.7` → `2.7.0`, `3` → `3.0.0`) and surrounding whitespace.
///
/// Never compare raw version strings lexically: `"2.10.0" < "2.9.0"` is true
/// for strings and false for versions.
@immutable
class SemanticVersion implements Comparable<SemanticVersion> {
  /// Creates a version from its components.
  const SemanticVersion(
    this.major,
    this.minor,
    this.patch, {
    this.preRelease = const [],
    this.build = const [],
  })  : assert(major >= 0, 'major must be >= 0'),
        assert(minor >= 0, 'minor must be >= 0'),
        assert(patch >= 0, 'patch must be >= 0');

  /// Parses [input], throwing [VersionFormatException] on failure.
  factory SemanticVersion.parse(String input) {
    final parsed = tryParse(input);
    if (parsed == null) {
      throw VersionFormatException(input);
    }
    return parsed;
  }

  /// Parses [input], returning `null` on failure.
  static SemanticVersion? tryParse(String? input) {
    if (input == null) return null;
    var text = input.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('v') || text.startsWith('V')) {
      text = text.substring(1);
    }

    // Split off build metadata first, then pre-release.
    List<String> build = const [];
    final plus = text.indexOf('+');
    if (plus >= 0) {
      final meta = text.substring(plus + 1);
      text = text.substring(0, plus);
      if (meta.isEmpty) return null;
      build = meta.split('.');
      if (build.any((id) => !_isValidIdentifier(id))) return null;
    }

    List<String> preRelease = const [];
    final dash = text.indexOf('-');
    if (dash >= 0) {
      final pre = text.substring(dash + 1);
      text = text.substring(0, dash);
      if (pre.isEmpty) return null;
      preRelease = pre.split('.');
      if (preRelease.any((id) => !_isValidIdentifier(id))) return null;
    }

    final core = text.split('.');
    if (core.isEmpty || core.length > 3) return null;
    final numbers = <int>[];
    for (final part in core) {
      if (part.isEmpty || !_numeric.hasMatch(part)) return null;
      final n = int.tryParse(part);
      if (n == null) return null;
      numbers.add(n);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return SemanticVersion(
      numbers[0],
      numbers[1],
      numbers[2],
      preRelease: List.unmodifiable(preRelease),
      build: List.unmodifiable(build),
    );
  }

  static final RegExp _numeric = RegExp(r'^[0-9]+$');
  static final RegExp _identifier = RegExp(r'^[0-9A-Za-z-]+$');

  static bool _isValidIdentifier(String id) =>
      id.isNotEmpty && _identifier.hasMatch(id);

  /// The major component.
  final int major;

  /// The minor component.
  final int minor;

  /// The patch component.
  final int patch;

  /// Pre-release identifiers (empty for a stable release).
  final List<String> preRelease;

  /// Build metadata identifiers (ignored for ordering).
  final List<String> build;

  /// Whether this is a pre-release (has at least one pre-release identifier).
  bool get isPreRelease => preRelease.isNotEmpty;

  /// The version with pre-release and build metadata stripped.
  SemanticVersion get core => SemanticVersion(major, minor, patch);

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return _comparePreRelease(preRelease, other.preRelease);
  }

  static int _comparePreRelease(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 0;
    // A release has higher precedence than any of its pre-releases.
    if (a.isEmpty) return 1;
    if (b.isEmpty) return -1;
    final length = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final x = a[i];
      final y = b[i];
      final xn = _numeric.hasMatch(x) ? int.parse(x) : null;
      final yn = _numeric.hasMatch(y) ? int.parse(y) : null;
      if (xn != null && yn != null) {
        if (xn != yn) return xn.compareTo(yn);
      } else if (xn != null) {
        return -1; // numeric < alphanumeric
      } else if (yn != null) {
        return 1;
      } else {
        final c = x.compareTo(y);
        if (c != 0) return c;
      }
    }
    return a.length.compareTo(b.length);
  }

  /// `this < other`.
  bool operator <(SemanticVersion other) => compareTo(other) < 0;

  /// `this <= other`.
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;

  /// `this > other`.
  bool operator >(SemanticVersion other) => compareTo(other) > 0;

  /// `this >= other`.
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease.join('.'));

  @override
  String toString() {
    final buffer = StringBuffer('$major.$minor.$patch');
    if (preRelease.isNotEmpty) buffer.write('-${preRelease.join('.')}');
    if (build.isNotEmpty) buffer.write('+${build.join('.')}');
    return buffer.toString();
  }
}
