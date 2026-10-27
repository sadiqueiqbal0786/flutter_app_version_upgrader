/// The release channel a build belongs to.
///
/// A production install must never be shown beta release information, so the
/// channel is part of every API request and every cache key.
enum VersionChannel {
  /// Public store release.
  production('production'),

  /// Open or closed beta (Play Store testing tracks, TestFlight external).
  beta('beta'),

  /// Early alpha builds.
  alpha('alpha'),

  /// Internal-only builds.
  internal('internal');

  const VersionChannel(this.wireName);

  /// The value used in API requests and responses.
  final String wireName;

  /// Resolves a wire name, returning `null` for unknown values.
  static VersionChannel? fromWireName(String? name) {
    if (name == null) return null;
    final lower = name.trim().toLowerCase();
    for (final channel in values) {
      if (channel.wireName == lower) return channel;
    }
    return null;
  }
}
