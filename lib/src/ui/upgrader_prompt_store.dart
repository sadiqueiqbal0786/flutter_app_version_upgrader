import 'dart:convert';

import '../models/version_info.dart';
import '../platform/flutter_app_version_upgrader_platform_interface.dart';

/// Remembers the user's answers to the soft prompt ("skip this version",
/// "later") in the plugin's native cache, so they survive restarts.
class UpgraderPromptStore {
  /// Creates a store backed by [platform].
  UpgraderPromptStore(this._platform, {DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  static const _key = 'flutter_app_version_upgrader.prompt';

  final FlutterAppVersionUpgraderPlatform _platform;
  final DateTime Function() _clock;

  Map<String, dynamic> _state = {};
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _platform.readCache(_key);
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is Map) _state = Map<String, dynamic>.from(decoded);
    } on Object {
      _state = {};
    }
  }

  Future<void> _save() async {
    try {
      await _platform.writeCache(_key, jsonEncode(_state));
    } on Object {
      // Losing a "skip" is harmless; the prompt simply shows again.
    }
  }

  /// Records that [version] should not be offered again.
  Future<void> skip(VersionInfo version) async {
    await _load();
    _state['skipped'] = version.toJson();
    _state.remove('remind_at');
    await _save();
  }

  /// Records that the prompt may show again after [delay].
  Future<void> remindLater(Duration delay) async {
    await _load();
    _state['remind_at'] = _clock().add(delay).toIso8601String();
    await _save();
  }

  /// Whether the prompt for [latest] should be suppressed right now.
  Future<bool> isSuppressed(VersionInfo latest) async {
    await _load();
    final skipped = VersionInfo.fromJson(
      (_state['skipped'] as Map?)?.cast<String, dynamic>(),
    );
    if (skipped != null && skipped.compareTo(latest) == 0) return true;
    final remindAt = DateTime.tryParse(_state['remind_at'] as String? ?? '');
    if (remindAt != null && _clock().isBefore(remindAt)) return true;
    return false;
  }

  /// Forgets everything.
  Future<void> clear() async {
    _state = {};
    _loaded = true;
    try {
      await _platform.clearCache(_key);
    } on Object {
      // ignore
    }
  }
}
