import 'package:meta/meta.dart';

import 'models/version_channel.dart';
import 'models/version_info.dart';

/// What `VersionManager.check()` reports when neither the API nor the cache
/// can provide a policy.
enum FailurePolicy {
  /// Let the application continue (`isBlocked == false`). The default.
  ///
  /// A backend outage must not lock every user out of the app.
  open,

  /// Block the application (`isBlocked == true`). Use only when running an
  /// unverified version is a bigger risk than an outage.
  closed,
}

/// Validates a raw API response before it is trusted.
///
/// Return `false` to reject the response (it is then treated as a network
/// failure and the cache is consulted). Use this to verify a response
/// signature header, for example an HMAC the backend computes over the body.
typedef ResponseValidator = bool Function(
  String body,
  Map<String, String> headers,
);

/// Receives diagnostic messages from the plugin.
typedef VersionLogger = void Function(String message, [Object? error]);

/// Configuration for `VersionManager`.
@immutable
class VersionManagerConfig {
  /// Creates a [VersionManagerConfig].
  const VersionManagerConfig({
    required this.baseUrl,
    this.appId,
    this.channel = VersionChannel.production,
    this.checkPath = '/v1/version/check',
    this.apiKey,
    this.headers = const {},
    this.timeout = const Duration(seconds: 10),
    this.cacheTtl = const Duration(hours: 24),
    this.allowStaleCache = true,
    this.failurePolicy = FailurePolicy.open,
    this.responseValidator,
    this.appStoreId,
    this.currentVersionOverride,
    this.logger,
  });

  /// Base URL of the version API, e.g. `https://versions.example.com`.
  final String baseUrl;

  /// Application identifier sent to the backend.
  ///
  /// Defaults to the installed package name / bundle identifier.
  final String? appId;

  /// The release channel this build belongs to.
  final VersionChannel channel;

  /// Path of the check endpoint, appended to [baseUrl].
  final String checkPath;

  /// Optional API key sent as the `X-Api-Key` header.
  final String? apiKey;

  /// Extra headers sent with every request.
  final Map<String, String> headers;

  /// Network timeout for a single check.
  final Duration timeout;

  /// How long a cached response is considered fresh.
  final Duration cacheTtl;

  /// When the API is unreachable and the cache has expired, whether to use
  /// the expired entry anyway (`isStale` is set on the result).
  ///
  /// When `false`, an expired cache is treated as no cache.
  final bool allowStaleCache;

  /// What to do when no policy data is available at all.
  final FailurePolicy failurePolicy;

  /// Optional response integrity check (e.g. signature verification).
  final ResponseValidator? responseValidator;

  /// The numeric App Store id, used as a fallback store link on iOS when the
  /// backend does not supply `update.url`.
  final String? appStoreId;

  /// Overrides the installed version. Intended for tests and debug menus.
  final VersionInfo? currentVersionOverride;

  /// Receives diagnostic log messages.
  final VersionLogger? logger;

  /// Returns a copy with the given fields replaced.
  VersionManagerConfig copyWith({
    String? baseUrl,
    String? appId,
    VersionChannel? channel,
    String? checkPath,
    String? apiKey,
    Map<String, String>? headers,
    Duration? timeout,
    Duration? cacheTtl,
    bool? allowStaleCache,
    FailurePolicy? failurePolicy,
    ResponseValidator? responseValidator,
    String? appStoreId,
    VersionInfo? currentVersionOverride,
    VersionLogger? logger,
  }) => VersionManagerConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    appId: appId ?? this.appId,
    channel: channel ?? this.channel,
    checkPath: checkPath ?? this.checkPath,
    apiKey: apiKey ?? this.apiKey,
    headers: headers ?? this.headers,
    timeout: timeout ?? this.timeout,
    cacheTtl: cacheTtl ?? this.cacheTtl,
    allowStaleCache: allowStaleCache ?? this.allowStaleCache,
    failurePolicy: failurePolicy ?? this.failurePolicy,
    responseValidator: responseValidator ?? this.responseValidator,
    appStoreId: appStoreId ?? this.appStoreId,
    currentVersionOverride:
        currentVersionOverride ?? this.currentVersionOverride,
    logger: logger ?? this.logger,
  );
}
