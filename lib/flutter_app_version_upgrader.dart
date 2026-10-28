/// Remote-controlled app version management for Flutter.
///
/// The plugin asks a version API which release is the latest and which is
/// the minimum the administrator still allows, compares both against the
/// installed version, and returns a [VersionCheckResult]. It never shows UI.
///
/// See [VersionManager] for the entry point and [VersionManagerConfig] for
/// the available options.
library;

export 'src/models/app_info.dart';
export 'src/models/cached_policy.dart';
export 'src/models/semantic_version.dart';
export 'src/models/version_channel.dart';
export 'src/models/version_check_response.dart';
export 'src/models/version_check_result.dart';
export 'src/models/version_info.dart';
export 'src/models/version_policy.dart';
export 'src/platform/flutter_app_version_upgrader_method_channel.dart';
export 'src/platform/flutter_app_version_upgrader_platform_interface.dart';
export 'src/platform/in_memory_platform.dart';
export 'src/services/policy_cache_service.dart';
export 'src/services/store_launcher.dart';
export 'src/services/version_api_client.dart';
export 'src/services/version_source.dart';
export 'src/version_manager.dart';
export 'src/version_manager_config.dart';
