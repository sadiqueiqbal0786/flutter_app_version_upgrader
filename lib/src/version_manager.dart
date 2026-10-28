import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models/app_info.dart';
import 'models/cached_policy.dart';
import 'models/semantic_version.dart';
import 'models/version_check_result.dart';
import 'models/version_info.dart';
import 'platform/flutter_app_version_upgrader_platform_interface.dart';
import 'platform/in_memory_platform.dart';
import 'services/policy_cache_service.dart';
import 'services/store_launcher.dart';
import 'services/version_api_client.dart';
import 'services/version_source.dart';
import 'version_manager_config.dart';

/// Entry point of the plugin.
///
/// Typical use:
///
/// ```dart
/// await VersionManager.initialize(
///   const VersionManagerConfig(
///     baseUrl: 'https://versions.example.com',
///     channel: VersionChannel.production,
///   ),
/// );
///
/// final result = await VersionManager.check();
/// if (result.isUpdateRequired) {
///   // Show a blocking dialog, then:
///   await VersionManager.openStore(result);
/// }
/// ```
///
/// Instances can also be created directly (with injected dependencies) for
/// tests or for apps that prefer their own dependency injection.
///
/// Check flow:
///
/// 1. Read the installed version from the platform.
/// 2. Call the version API.
/// 3. On success, cache the response and evaluate it.
/// 4. On failure, evaluate the last cached response (marked stale if its TTL
///    has passed).
/// 5. With no cache, return [UpdateStatus.checkFailed]; whether that blocks
///    the app is decided by [VersionManagerConfig.failurePolicy].
class VersionManager {
  /// Creates a [VersionManager] with explicit dependencies.
  ///
  /// [source] replaces the HTTP client entirely; see [VersionSource]. When
  /// omitted, [VersionApiClient] talks to `config.baseUrl`.
  VersionManager(
    this.config, {
    FlutterAppVersionUpgraderPlatform? platform,
    http.Client? httpClient,
    VersionSource? source,
    @Deprecated('Use source') VersionApiClient? apiClient,
    DateTime Function()? clock,
  })  : _platform = platform ?? _defaultPlatform(),
        _clock = clock ?? _utcNow {
    _api = source ??
        // ignore: deprecated_member_use_from_same_package
        apiClient ??
        VersionApiClient(config: config, httpClient: httpClient);
    _cache = PolicyCacheService(_platform);
    _store = StoreLauncher(_platform);
  }

  static DateTime _utcNow() => DateTime.now().toUtc();

  /// Whether native support exists for the current platform.
  ///
  /// Only Android and iOS ship native code. Elsewhere the plugin falls back
  /// to [InMemoryFlutterAppVersionUpgraderPlatform] and never throws.
  static bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static FlutterAppVersionUpgraderPlatform _defaultPlatform() =>
      isPlatformSupported
          ? FlutterAppVersionUpgraderPlatform.instance
          : InMemoryFlutterAppVersionUpgraderPlatform();

  /// The configuration in effect.
  final VersionManagerConfig config;

  final FlutterAppVersionUpgraderPlatform _platform;
  final DateTime Function() _clock;
  late final VersionSource _api;
  late final PolicyCacheService _cache;
  late final StoreLauncher _store;

  AppInfo? _appInfo;
  Future<VersionCheckResult>? _inFlight;
  VersionCheckResult? _lastResult;
  final StreamController<VersionCheckResult> _results =
      StreamController<VersionCheckResult>.broadcast();

  /// The platform implementation in use (native on Android/iOS, in-memory
  /// elsewhere). The UI layer uses it to persist prompt choices.
  FlutterAppVersionUpgraderPlatform get platform => _platform;

  /// Alias of [platform] kept for tests.
  @visibleForTesting
  FlutterAppVersionUpgraderPlatform get platformForTesting => _platform;

  /// The most recent result produced by [check], if any.
  VersionCheckResult? get lastResult => _lastResult;

  /// Emits every result produced by [check].
  Stream<VersionCheckResult> get results => _results.stream;

  // ---------------------------------------------------------------------------
  // Static convenience API
  // ---------------------------------------------------------------------------

  static VersionManager? _instance;

  /// The shared instance created by [initialize].
  ///
  /// Throws [StateError] if [initialize] has not been called.
  static VersionManager get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'VersionManager.initialize() must be called before use.',
      );
    }
    return i;
  }

  /// Whether [initialize] has been called.
  static bool get isInitialized => _instance != null;

  /// Creates the shared instance and reads the installed version.
  ///
  /// Safe to call more than once; later calls replace the configuration.
  static Future<VersionManager> initialize(
    VersionManagerConfig config, {
    http.Client? httpClient,
    VersionSource? source,
  }) async {
    _instance?.dispose();
    final manager = VersionManager(
      config,
      httpClient: httpClient,
      source: source,
    );
    _instance = manager;
    try {
      await manager.loadAppInfo();
    } on Object catch (e) {
      // Unsupported platform or a native failure: check() will report it
      // as checkFailed rather than initialize() throwing.
      manager._log('Could not read app info during initialize', e);
    }
    return manager;
  }

  /// Runs a version check on the shared instance. See [checkVersion].
  static Future<VersionCheckResult> check({bool preferCache = false}) =>
      instance.checkVersion(preferCache: preferCache);

  /// Opens the store on the shared instance. See [openStoreFor].
  static Future<bool> openStore([VersionCheckResult? result]) =>
      instance.openStoreFor(result);

  /// Clears the cached policy on the shared instance. See [clearCachedPolicy].
  static Future<void> clearCache() => instance.clearCachedPolicy();

  /// Discards the shared instance. Mainly for tests.
  @visibleForTesting
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }

  // ---------------------------------------------------------------------------
  // Instance API
  // ---------------------------------------------------------------------------

  /// Reads (and memoises) the installed application info.
  Future<AppInfo> loadAppInfo() async {
    return _appInfo ??= await _platform.getAppInfo();
  }

  /// The app id sent to the backend.
  Future<String> resolveAppId() async =>
      config.appId ?? (await loadAppInfo()).packageName;

  /// The installed version, honouring [VersionManagerConfig.currentVersionOverride].
  Future<VersionInfo> resolveCurrentVersion() async {
    final override = config.currentVersionOverride;
    if (override != null) return override;
    return (await loadAppInfo()).toVersionInfo();
  }

  /// Runs a version check.
  ///
  /// Concurrent calls share one in-flight request. With [preferCache] set,
  /// an unexpired cached policy is returned without touching the network;
  /// use this on hot paths (e.g. every app resume) and a plain call on cold
  /// start.
  Future<VersionCheckResult> checkVersion({bool preferCache = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _run(preferCache: preferCache).whenComplete(() {
      _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  Future<VersionCheckResult> _run({required bool preferCache}) async {
    final now = _clock();
    final blockWhenUnknown = config.failurePolicy == FailurePolicy.closed;

    AppInfo appInfo;
    VersionInfo current;
    try {
      appInfo = await _loadAppInfoOrSynthesize();
      current = await resolveCurrentVersion();
      if ((config.appId ?? appInfo.packageName).isEmpty) {
        throw StateError(
          'appId is required in VersionManagerConfig on '
          '${InMemoryFlutterAppVersionUpgraderPlatform.hostPlatformName}.',
        );
      }
    } on Object catch (e, st) {
      _log('Could not read installed version', e, st);
      // Without a parsable installed version there is nothing to compare.
      // Use 0.0.0 so the failure surfaces as checkFailed rather than a throw.
      return _publish(
        VersionCheckResult.failed(
          current: const VersionInfo(SemanticVersion(0, 0, 0)),
          checkedAt: now,
          blockWhenUnknown: blockWhenUnknown,
          error: e,
        ),
      );
    }

    final appId = config.appId ?? appInfo.packageName;
    final key = PolicyCacheService.keyFor(
      appId: appId,
      platform: appInfo.platform,
      channel: config.channel,
    );

    CachedPolicy? cached;
    if (preferCache) {
      cached = await _readCache(key);
      if (cached != null && !cached.isExpiredAt(now)) {
        _log('Using fresh cached policy');
        return _publish(
          VersionCheckResult.evaluate(
            current: current,
            response: cached.response,
            source: CheckSource.cache,
            checkedAt: now,
          ),
        );
      }
    }

    Object? failure;
    try {
      final response = await _api.fetch(
        VersionCheckRequest(
          appId: appId,
          platform: appInfo.platform,
          channel: config.channel,
          current: current,
        ),
      );
      await _writeCache(
        key,
        CachedPolicy(
          response: response,
          receivedAt: now,
          expiresAt: now.add(config.cacheTtl),
        ),
      );
      return _publish(
        VersionCheckResult.evaluate(
          current: current,
          response: response,
          source: CheckSource.network,
          checkedAt: now,
        ),
      );
    } on Object catch (e, st) {
      failure = e;
      _log('Version API unavailable, falling back to cache', e, st);
    }

    cached ??= await _readCache(key);
    if (cached != null) {
      final expired = cached.isExpiredAt(now);
      if (!expired || config.allowStaleCache) {
        return _publish(
          VersionCheckResult.evaluate(
            current: current,
            response: cached.response,
            source: CheckSource.cache,
            checkedAt: now,
            isStale: expired,
          ),
        );
      }
      _log('Cached policy expired and stale use is disabled');
    }

    return _publish(
      VersionCheckResult.failed(
        current: current,
        checkedAt: now,
        blockWhenUnknown: blockWhenUnknown,
        error: failure,
      ),
    );
  }

  /// On platforms without native code, a configured `currentVersionOverride`
  /// is enough to run a check: synthesize the app info from the config.
  Future<AppInfo> _loadAppInfoOrSynthesize() async {
    try {
      return await loadAppInfo();
    } on UnsupportedError {
      final override = config.currentVersionOverride;
      final appId = config.appId;
      if (override == null || appId == null) rethrow;
      return _appInfo = AppInfo(
        packageName: appId,
        versionName: override.version.toString(),
        buildNumber: override.build,
        platform: InMemoryFlutterAppVersionUpgraderPlatform.hostPlatformName,
      );
    }
  }

  /// Opens the store page for [result] (defaults to [lastResult]).
  ///
  /// Uses the backend-supplied `update.url` when present, otherwise the
  /// platform store listing for the installed package / configured
  /// [VersionManagerConfig.appStoreId].
  Future<bool> openStoreFor([VersionCheckResult? result]) async {
    final target = result ?? _lastResult;
    String? packageName = _appInfo?.packageName ?? config.appId;
    if (packageName == null) {
      try {
        packageName = (await loadAppInfo()).packageName;
      } on Object catch (e) {
        _log('Could not read app info for openStore', e);
        return false;
      }
    }
    try {
      return await _store.open(
        url: target?.updateUrl,
        packageName: packageName,
        appStoreId: config.appStoreId,
      );
    } on Object catch (e) {
      _log('Could not open store', e);
      return false;
    }
  }

  /// Removes the cached policy for this app / platform / channel.
  Future<void> clearCachedPolicy() async {
    try {
      final appInfo = await _loadAppInfoOrSynthesize();
      final key = PolicyCacheService.keyFor(
        appId: config.appId ?? appInfo.packageName,
        platform: appInfo.platform,
        channel: config.channel,
      );
      await _cache.clear(key);
    } on Object catch (e, st) {
      _log('Could not clear cache', e, st);
    }
  }

  /// Releases resources. The instance must not be used afterwards.
  void dispose() {
    _api.close();
    _results.close();
  }

  Future<CachedPolicy?> _readCache(String key) async {
    try {
      return await _cache.read(key);
    } on Object catch (e, st) {
      _log('Could not read cache', e, st);
      return null;
    }
  }

  Future<void> _writeCache(String key, CachedPolicy policy) async {
    try {
      await _cache.write(key, policy);
    } on Object catch (e, st) {
      // A cache write failure must never fail the check itself.
      _log('Could not write cache', e, st);
    }
  }

  VersionCheckResult _publish(VersionCheckResult result) {
    _lastResult = result;
    if (!_results.isClosed) _results.add(result);
    return result;
  }

  void _log(String message, [Object? error, StackTrace? stackTrace]) {
    config.logger?.call(message, error);
  }
}
