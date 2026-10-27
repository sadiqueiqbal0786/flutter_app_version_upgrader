import 'package:meta/meta.dart';

import 'version_check_response.dart';
import 'version_info.dart';
import 'version_policy.dart';

/// The outcome of a version check.
enum UpdateStatus {
  /// The installed version is the latest published version (or newer).
  upToDate,

  /// A newer version exists but the installed one is still allowed to run.
  updateAvailable,

  /// The installed version is below the minimum and the policy forces an
  /// update. The host app should block normal use until the user updates.
  updateRequired,

  /// No decision could be made: the API and the cache were both unavailable
  /// or invalid. Consult [VersionCheckResult.isBlocked] for what to do.
  checkFailed,
}

/// Where the policy data behind a [VersionCheckResult] came from.
enum CheckSource {
  /// Fresh data from the version API.
  network,

  /// The last successful API response, served from the local cache.
  cache,

  /// Nothing was available.
  none,
}

/// The decision returned by `VersionManager.check()`.
///
/// The plugin never shows UI. The host application reads [status] (and the
/// convenience getters) and decides what to present.
@immutable
class VersionCheckResult {
  /// Creates a [VersionCheckResult].
  const VersionCheckResult({
    required this.status,
    required this.source,
    required this.current,
    required this.checkedAt,
    this.latest,
    this.minimum,
    this.recommended,
    this.policy,
    this.updateUrl,
    this.updateMessage,
    this.releaseNotes,
    this.isStale = false,
    this.error,
  }) : _blockWhenUnknown = false;

  /// Builds a result for the case where no policy data was available.
  const VersionCheckResult.failed({
    required this.current,
    required this.checkedAt,
    required bool blockWhenUnknown,
    this.error,
  }) : status = UpdateStatus.checkFailed,
       source = CheckSource.none,
       latest = null,
       minimum = null,
       recommended = null,
       policy = null,
       updateUrl = null,
       updateMessage = null,
       releaseNotes = null,
       isStale = false,
       // ignore: prefer_initializing_formals
       _blockWhenUnknown = blockWhenUnknown;

  /// Builds a result by comparing [current] against [response].
  ///
  /// Decision rules, in order:
  ///
  /// 1. If the policy is disabled, the result is never `updateRequired`.
  /// 2. `current < minimum` and `policy.forceUpdate` → `updateRequired`.
  /// 3. `current < latest` → `updateAvailable`.
  /// 4. Otherwise → `upToDate`.
  factory VersionCheckResult.evaluate({
    required VersionInfo current,
    required VersionCheckResponse response,
    required CheckSource source,
    required DateTime checkedAt,
    bool isStale = false,
  }) {
    final policy = response.policy;
    final belowMinimum = current < response.minimum;
    final belowLatest = current < response.latest;

    UpdateStatus status;
    if (policy.enabled && policy.forceUpdate && belowMinimum) {
      status = UpdateStatus.updateRequired;
    } else if (belowLatest || belowMinimum) {
      status = UpdateStatus.updateAvailable;
    } else {
      status = UpdateStatus.upToDate;
    }

    return VersionCheckResult(
      status: status,
      source: source,
      current: current,
      checkedAt: checkedAt,
      latest: response.latest,
      minimum: response.minimum,
      recommended: response.recommended,
      policy: policy,
      updateUrl: response.updateUrl,
      updateMessage: policy.updateMessage,
      releaseNotes: response.releaseNotes,
      isStale: isStale,
    );
  }

  /// The computed state.
  final UpdateStatus status;

  /// Where the policy data came from.
  final CheckSource source;

  /// The installed version and build.
  final VersionInfo current;

  /// When this check completed (UTC).
  final DateTime checkedAt;

  /// The newest published version, if known.
  final VersionInfo? latest;

  /// The minimum supported version, if known.
  final VersionInfo? minimum;

  /// The recommended version, if the server provides one.
  final VersionInfo? recommended;

  /// The policy the server applied, if known.
  final VersionPolicy? policy;

  /// Store page or download URL for the update, if known.
  final String? updateUrl;

  /// Admin-configured message to show users who should update.
  final String? updateMessage;

  /// Release notes for [latest], if provided.
  final String? releaseNotes;

  /// `true` when [source] is [CheckSource.cache] and the cache entry had
  /// already passed its TTL. The data is the last known good policy, not
  /// current truth.
  final bool isStale;

  /// The error that caused a [UpdateStatus.checkFailed], if any.
  final Object? error;

  final bool _blockWhenUnknown;

  /// A newer version than [current] exists.
  bool get isUpdateAvailable =>
      status == UpdateStatus.updateAvailable ||
      status == UpdateStatus.updateRequired;

  /// The user must update before continuing.
  bool get isUpdateRequired => status == UpdateStatus.updateRequired;

  /// Whether the installed version is below the minimum, regardless of
  /// whether the policy forces an update.
  bool get isBelowMinimum {
    final min = minimum;
    return min != null && current < min;
  }

  /// Whether the installed version is below the recommended version.
  bool get isBelowRecommended {
    final rec = recommended;
    return rec != null && current < rec;
  }

  /// Whether the check could not be completed.
  bool get isFailed => status == UpdateStatus.checkFailed;

  /// Whether the host app should block normal use.
  ///
  /// `true` for [UpdateStatus.updateRequired]. For
  /// [UpdateStatus.checkFailed] it reflects the configured failure policy:
  /// fail-open (the default) returns `false`, fail-closed returns `true`.
  bool get isBlocked =>
      status == UpdateStatus.updateRequired ||
      (status == UpdateStatus.checkFailed && _blockWhenUnknown);

  /// A debug-friendly map of this result.
  Map<String, dynamic> toJson() => {
    'status': status.name,
    'source': source.name,
    'current': current.toJson(),
    if (latest != null) 'latest': latest!.toJson(),
    if (minimum != null) 'minimum': minimum!.toJson(),
    if (recommended != null) 'recommended': recommended!.toJson(),
    if (policy != null) 'policy': policy!.toJson(),
    if (updateUrl != null) 'update_url': updateUrl,
    if (updateMessage != null) 'update_message': updateMessage,
    if (releaseNotes != null) 'release_notes': releaseNotes,
    'is_update_available': isUpdateAvailable,
    'is_update_required': isUpdateRequired,
    'is_blocked': isBlocked,
    'is_stale': isStale,
    'checked_at': checkedAt.toUtc().toIso8601String(),
    if (error != null) 'error': error.toString(),
  };

  @override
  String toString() =>
      'VersionCheckResult(${status.name}, current: $current, latest: $latest, '
      'minimum: $minimum, source: ${source.name}'
      '${isStale ? ', stale' : ''})';
}
