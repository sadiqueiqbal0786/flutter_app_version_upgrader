import 'package:meta/meta.dart';

/// How the backend derives the minimum supported version.
enum PolicyMode {
  /// `minimum = latest published version`. The default.
  autoLatest('auto_latest'),

  /// An administrator has pinned an explicit minimum version.
  custom('custom'),

  /// The minimum is the oldest release younger than a configured age.
  ageBased('age_based'),

  /// The server returned a mode this client does not know about.
  unknown('unknown');

  const PolicyMode(this.wireName);

  /// The value used in API responses.
  final String wireName;

  /// Resolves a wire name, mapping unrecognised values to [unknown].
  static PolicyMode fromWireName(String? name) {
    if (name == null) return unknown;
    final lower = name.trim().toLowerCase();
    for (final mode in values) {
      if (mode.wireName == lower) return mode;
    }
    return unknown;
  }
}

/// The policy block of a version check response.
@immutable
class VersionPolicy {
  /// Creates a [VersionPolicy].
  const VersionPolicy({
    required this.mode,
    required this.forceUpdate,
    this.enabled = true,
    this.updateMessage,
  });

  /// Parses the `policy` object of an API response.
  factory VersionPolicy.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const VersionPolicy(mode: PolicyMode.unknown, forceUpdate: false);
    }
    return VersionPolicy(
      mode: PolicyMode.fromWireName(json['mode'] as String?),
      forceUpdate: _toBool(json['force_update'], fallback: false),
      enabled: _toBool(json['enabled'], fallback: true),
      updateMessage: json['update_message'] as String?,
    );
  }

  static bool _toBool(Object? value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return fallback;
  }

  /// How the minimum version was derived.
  final PolicyMode mode;

  /// Whether installs below the minimum must update before continuing.
  ///
  /// When `false`, being below the minimum still surfaces as
  /// `UpdateStatus.updateAvailable`, never as `updateRequired`.
  final bool forceUpdate;

  /// Whether version enforcement is switched on at all.
  ///
  /// A disabled policy always yields `UpdateStatus.upToDate` or
  /// `UpdateStatus.updateAvailable`, never `updateRequired`.
  final bool enabled;

  /// Optional message the admin wants shown to users who must update.
  final String? updateMessage;

  /// Serialises to the wire format.
  Map<String, dynamic> toJson() => {
        'mode': mode.wireName,
        'force_update': forceUpdate,
        'enabled': enabled,
        if (updateMessage != null) 'update_message': updateMessage,
      };

  @override
  bool operator ==(Object other) =>
      other is VersionPolicy &&
      other.mode == mode &&
      other.forceUpdate == forceUpdate &&
      other.enabled == enabled &&
      other.updateMessage == updateMessage;

  @override
  int get hashCode => Object.hash(mode, forceUpdate, enabled, updateMessage);

  @override
  String toString() =>
      'VersionPolicy(mode: ${mode.wireName}, forceUpdate: $forceUpdate, '
      'enabled: $enabled)';
}
