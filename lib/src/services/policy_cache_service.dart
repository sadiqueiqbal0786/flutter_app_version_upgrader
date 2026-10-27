import 'dart:convert';

import '../models/cached_policy.dart';
import '../models/version_channel.dart';
import '../platform/flutter_app_version_upgrader_platform_interface.dart';

/// Persists the last successful API response via the native layer
/// (`SharedPreferences` on Android, `UserDefaults` on iOS).
class PolicyCacheService {
  /// Creates a [PolicyCacheService].
  PolicyCacheService(this._platform);

  final FlutterAppVersionUpgraderPlatform _platform;

  /// Builds the cache key for an app / platform / channel triple.
  ///
  /// Including the channel guarantees a production install can never read a
  /// cached beta policy.
  static String keyFor({
    required String appId,
    required String platform,
    required VersionChannel channel,
  }) =>
      'flutter_app_version_upgrader.policy.$appId.$platform.${channel.wireName}';

  /// Reads the cached policy under [key], or `null` if absent or corrupt.
  Future<CachedPolicy?> read(String key) async {
    final raw = await _platform.readCache(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return CachedPolicy.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    }
  }

  /// Stores [policy] under [key].
  Future<void> write(String key, CachedPolicy policy) =>
      _platform.writeCache(key, jsonEncode(policy.toJson()));

  /// Removes the entry under [key].
  Future<void> clear(String key) => _platform.clearCache(key);
}
