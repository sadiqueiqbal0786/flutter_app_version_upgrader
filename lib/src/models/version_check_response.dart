import 'package:meta/meta.dart';

import 'version_channel.dart';
import 'version_info.dart';
import 'version_policy.dart';

/// Thrown when the version API returns a body the client cannot use.
class VersionResponseException implements Exception {
  /// Creates a [VersionResponseException].
  const VersionResponseException(this.message);

  /// Explanation of what was wrong.
  final String message;

  @override
  String toString() => 'VersionResponseException: $message';
}

/// The parsed payload of `GET /v1/version/check`.
///
/// The server returns *data*, not a verdict. The client computes the final
/// state by comparing the installed version against [latest], [minimum] and
/// [recommended], so the same response can drive different UIs.
@immutable
class VersionCheckResponse {
  /// Creates a [VersionCheckResponse].
  const VersionCheckResponse({
    required this.schemaVersion,
    required this.appId,
    required this.platform,
    required this.channel,
    required this.latest,
    required this.minimum,
    required this.policy,
    this.recommended,
    this.updateUrl,
    this.releaseNotes,
    this.serverTime,
  });

  /// The newest schema this client understands.
  static const int supportedSchemaVersion = 1;

  /// Parses a decoded JSON body.
  ///
  /// Throws [VersionResponseException] when required fields are missing or
  /// the schema version is newer than [supportedSchemaVersion].
  factory VersionCheckResponse.fromJson(Map<String, dynamic> json) {
    final schema = _toInt(json['schema_version']) ?? 1;
    if (schema > supportedSchemaVersion) {
      throw VersionResponseException(
        'schema_version $schema is newer than supported '
        '$supportedSchemaVersion',
      );
    }
    final app = _map(json['app']);
    final latest = VersionInfo.fromJson(_map(json['latest']));
    if (latest == null) {
      throw const VersionResponseException('missing or invalid "latest"');
    }
    // Default the minimum to the latest release: this is the AUTO_LATEST
    // policy and also the safest interpretation of a response that omits it.
    final minimum = VersionInfo.fromJson(_map(json['minimum'])) ?? latest;
    final update = _map(json['update']);
    return VersionCheckResponse(
      schemaVersion: schema,
      appId: app?['id'] as String? ?? '',
      platform: app?['platform'] as String? ?? '',
      channel: VersionChannel.fromWireName(app?['channel'] as String?) ??
          VersionChannel.production,
      latest: latest,
      minimum: minimum,
      recommended: VersionInfo.fromJson(_map(json['recommended'])),
      policy: VersionPolicy.fromJson(_map(json['policy'])),
      updateUrl: _nonEmpty(update?['url'] as String?),
      releaseNotes: _nonEmpty(update?['release_notes'] as String?) ??
          _nonEmpty(json['release_notes'] as String?),
      serverTime: _toDate(json['server_time']),
    );
  }

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

  static DateTime? _toDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  /// The response schema version.
  final int schemaVersion;

  /// Application identifier echoed by the server.
  final String appId;

  /// Platform echoed by the server (`android` / `ios`).
  final String platform;

  /// Channel echoed by the server.
  final VersionChannel channel;

  /// The newest published release on this platform and channel.
  final VersionInfo latest;

  /// The oldest version still allowed to run.
  final VersionInfo minimum;

  /// The version users are encouraged (not forced) to move to, if any.
  final VersionInfo? recommended;

  /// The policy the server applied.
  final VersionPolicy policy;

  /// Store page or download URL for the update.
  final String? updateUrl;

  /// Optional release notes for [latest].
  final String? releaseNotes;

  /// Server clock at response time, if provided.
  final DateTime? serverTime;

  /// Serialises back to the wire format (used by the local cache).
  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'app': {
          'id': appId,
          'platform': platform,
          'channel': channel.wireName,
        },
        'latest': latest.toJson(),
        'minimum': minimum.toJson(),
        if (recommended != null) 'recommended': recommended!.toJson(),
        'policy': policy.toJson(),
        'update': {
          if (updateUrl != null) 'url': updateUrl,
          if (releaseNotes != null) 'release_notes': releaseNotes,
        },
        if (serverTime != null)
          'server_time': serverTime!.toUtc().toIso8601String(),
      };

  @override
  String toString() =>
      'VersionCheckResponse(latest: $latest, minimum: $minimum, '
      'recommended: $recommended, policy: $policy)';
}
