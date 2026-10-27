import 'package:meta/meta.dart';

import 'version_check_response.dart';

/// A [VersionCheckResponse] stored locally with its receipt and expiry times.
///
/// The cache protects users from transient backend or network outages: when
/// the API cannot be reached, the last successful response is reused.
@immutable
class CachedPolicy {
  /// Creates a [CachedPolicy].
  const CachedPolicy({
    required this.response,
    required this.receivedAt,
    required this.expiresAt,
  });

  /// Parses a cache envelope previously produced by [toJson].
  ///
  /// Returns `null` if the envelope is malformed, so a corrupt cache behaves
  /// like an empty one.
  static CachedPolicy? fromJson(Map<String, dynamic> json) {
    try {
      final body = json['response'];
      final received = DateTime.tryParse(json['received_at'] as String? ?? '');
      final expires = DateTime.tryParse(json['expires_at'] as String? ?? '');
      if (body is! Map || received == null || expires == null) return null;
      return CachedPolicy(
        response:
            VersionCheckResponse.fromJson(Map<String, dynamic>.from(body)),
        receivedAt: received.toUtc(),
        expiresAt: expires.toUtc(),
      );
    } on Object {
      return null;
    }
  }

  /// The cached API response.
  final VersionCheckResponse response;

  /// When the response was received (UTC).
  final DateTime receivedAt;

  /// When the entry should be considered stale (UTC).
  final DateTime expiresAt;

  /// Whether [now] is past [expiresAt].
  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt);

  /// Serialises the envelope.
  Map<String, dynamic> toJson() => {
        'cache_version': 1,
        'response': response.toJson(),
        'received_at': receivedAt.toUtc().toIso8601String(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
      };
}
