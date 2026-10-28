import 'dart:async';

import 'package:meta/meta.dart';

import '../models/version_channel.dart';
import '../models/version_check_response.dart';
import '../models/version_info.dart';

/// What the plugin knows when it asks for a version policy.
@immutable
class VersionCheckRequest {
  /// Creates a request.
  const VersionCheckRequest({
    required this.appId,
    required this.platform,
    required this.channel,
    required this.current,
  });

  /// Application id (package name / bundle id unless overridden).
  final String appId;

  /// `android`, `ios`, or the host platform name elsewhere.
  final String platform;

  /// Release channel of this build.
  final VersionChannel channel;

  /// Installed version and build.
  final VersionInfo current;

  @override
  String toString() =>
      'VersionCheckRequest($appId $platform/${channel.wireName} $current)';
}

/// Where version policies come from.
///
/// The plugin ships [VersionApiClient], an HTTP implementation of the
/// documented contract. Implement this interface to use anything else:
/// your own REST or GraphQL API with a different payload, Firebase Remote
/// Config, a config file bundled with the app, or a fake in tests.
///
/// Return a [VersionCheckResponse]; throw on failure and the plugin falls
/// back to its cache and then fails open or closed as configured.
///
/// ```dart
/// class RemoteConfigSource implements VersionSource {
///   @override
///   Future<VersionCheckResponse> fetch(VersionCheckRequest request) async {
///     final rc = FirebaseRemoteConfig.instance;
///     await rc.fetchAndActivate();
///     return VersionCheckResponse(
///       schemaVersion: 1,
///       appId: request.appId,
///       platform: request.platform,
///       channel: request.channel,
///       latest: VersionInfo.parse(rc.getString('latest_version')),
///       minimum: VersionInfo.parse(rc.getString('min_version')),
///       policy: const VersionPolicy(mode: PolicyMode.custom, forceUpdate: true),
///       updateUrl: rc.getString('store_url'),
///     );
///   }
/// }
/// ```
abstract class VersionSource {
  /// Fetches the policy for [request].
  Future<VersionCheckResponse> fetch(VersionCheckRequest request);

  /// Wraps a plain function as a [VersionSource].
  factory VersionSource.fromCallback(
    Future<VersionCheckResponse> Function(VersionCheckRequest request) fetch,
  ) = _CallbackVersionSource;

  /// Releases resources. Called when the owning [VersionManager] is disposed.
  void close() {}
}

class _CallbackVersionSource implements VersionSource {
  _CallbackVersionSource(this._fetch);

  final Future<VersionCheckResponse> Function(VersionCheckRequest) _fetch;

  @override
  Future<VersionCheckResponse> fetch(VersionCheckRequest request) =>
      _fetch(request);

  @override
  void close() {}
}
