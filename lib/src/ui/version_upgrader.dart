import 'dart:async';

import 'package:flutter/material.dart';

import '../models/version_check_result.dart';
import '../models/version_info.dart';
import '../version_manager.dart';
import 'update_available_prompt.dart';
import 'update_required_screen.dart';
import 'upgrader_prompt_store.dart';
import 'upgrader_style.dart';
import 'upgrader_texts.dart';

/// Builds a replacement for the blocking screen.
///
/// Call [onUpdate] to open the store. [result] carries versions, release
/// notes and the admin message.
typedef RequiredUpdateBuilder = Widget Function(
  BuildContext context,
  VersionCheckResult result,
  VoidCallback onUpdate,
);

/// Builds a replacement for the soft prompt.
///
/// Call [onUpdate] to open the store, [onLater] to snooze, and [onSkip] to
/// never show this version again. The plugin persists the last two.
typedef AvailableUpdateBuilder = Widget Function(
  BuildContext context,
  VersionCheckResult result,
  VoidCallback onUpdate,
  VoidCallback onLater,
  VoidCallback onSkip,
);

/// Behavioural options for [VersionUpgrader].
@immutable
class UpgraderOptions {
  /// Creates the options.
  const UpgraderOptions({
    this.checkOnStart = true,
    this.checkOnResume = true,
    this.initialDelay = Duration.zero,
    this.showSoftPrompt = true,
    this.allowSkipVersion = true,
    this.allowLater = true,
    this.remindLaterAfter = const Duration(days: 1),
    this.softPromptOnlyBelowRecommended = false,
    this.blockWhenCheckFails = false,
  });

  /// Run a check after the first frame.
  final bool checkOnStart;

  /// Run a cache-first check whenever the app returns to the foreground.
  final bool checkOnResume;

  /// Wait before the first check (e.g. to let a splash finish).
  final Duration initialDelay;

  /// Show the non-blocking prompt for `updateAvailable`.
  final bool showSoftPrompt;

  /// Offer "Skip this version" on the soft prompt.
  final bool allowSkipVersion;

  /// Offer "Later" on the soft prompt. When false the barrier tap also
  /// acts as "Later" so the prompt is never un-dismissible.
  final bool allowLater;

  /// How long "Later" silences the prompt.
  final Duration remindLaterAfter;

  /// Show the soft prompt only when the backend sends a `recommended`
  /// version and the install is below it, instead of for every newer
  /// `latest`.
  final bool softPromptOnlyBelowRecommended;

  /// Show the blocking screen (with a retry button) when the check failed
  /// and the policy is fail-closed. Normally the plugin's `isBlocked` already
  /// encodes this; set `true` to force it regardless.
  final bool blockWhenCheckFails;
}

/// Drop-in widget that runs version checks and shows the built-in UI.
///
/// Place it inside `MaterialApp.builder` (so it covers every route) or
/// around your home widget:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => VersionUpgrader(child: child!),
/// )
/// ```
///
/// Requires `VersionManager.initialize(...)` to have been called. If it has
/// not, or the platform is unsupported, the widget simply renders [child].
///
/// Three layers of customisation:
/// * [texts] for wording and localisation,
/// * [style] for colours, shapes, icon or illustration and presentation,
/// * [requiredBuilder] / [availableBuilder] to replace the widgets entirely
///   while keeping the checking, skip and snooze logic.
class VersionUpgrader extends StatefulWidget {
  /// Creates the upgrader.
  const VersionUpgrader({
    super.key,
    required this.child,
    this.options = const UpgraderOptions(),
    this.style = const UpgraderStyle(),
    this.texts = const UpgraderTexts(),
    this.requiredBuilder,
    this.availableBuilder,
    this.onResult,
    this.onUpdatePressed,
    this.onSkipped,
    this.onLater,
    this.manager,
  });

  /// The host app.
  final Widget child;

  /// Behaviour.
  final UpgraderOptions options;

  /// Visual style.
  final UpgraderStyle style;

  /// Wording.
  final UpgraderTexts texts;

  /// Replaces the blocking screen.
  final RequiredUpdateBuilder? requiredBuilder;

  /// Replaces the soft prompt.
  final AvailableUpdateBuilder? availableBuilder;

  /// Called for every check result (analytics, logging).
  final ValueChanged<VersionCheckResult>? onResult;

  /// Called when the user taps update. Return `true` to suppress the default
  /// store launch (e.g. to open an in-app flow instead).
  final FutureOr<bool> Function(VersionCheckResult result)? onUpdatePressed;

  /// Called when the user skips a version.
  final ValueChanged<VersionInfo>? onSkipped;

  /// Called when the user taps later.
  final VoidCallback? onLater;

  /// Use a specific manager instead of `VersionManager.instance`.
  final VersionManager? manager;

  @override
  State<VersionUpgrader> createState() => VersionUpgraderState();
}

/// State of [VersionUpgrader]; exposed so hosts can trigger [check].
class VersionUpgraderState extends State<VersionUpgrader>
    with WidgetsBindingObserver {
  VersionManager? _manager;
  UpgraderPromptStore? _store;
  StreamSubscription<VersionCheckResult>? _subscription;
  VersionCheckResult? _result;
  bool _showSoft = false;
  Timer? _delay;

  /// The latest result, if any.
  VersionCheckResult? get result => _result;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(VersionUpgrader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.manager != oldWidget.manager) {
      _unbind();
      _result = null;
      _showSoft = false;
      _bind();
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  void _bind() {
    _manager = widget.manager ??
        (VersionManager.isInitialized ? VersionManager.instance : null);
    final m = _manager;
    if (m == null) return;
    _store = UpgraderPromptStore(m.platform);
    WidgetsBinding.instance.addObserver(this);
    _subscription = m.results.listen(_onResult);
    if (widget.options.checkOnStart) {
      _delay = Timer(widget.options.initialDelay, () => check());
    }
  }

  void _unbind() {
    _delay?.cancel();
    _delay = null;
    _subscription?.cancel();
    _subscription = null;
    if (_manager != null) WidgetsBinding.instance.removeObserver(this);
    _manager = null;
    _store = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.options.checkOnResume) {
      check(preferCache: true);
    }
  }

  /// Runs a check now.
  Future<void> check({bool preferCache = false}) async {
    final m = _manager;
    if (m == null) return;
    try {
      await m.checkVersion(preferCache: preferCache);
    } on Object catch (e) {
      debugPrint('[flutter_app_version_upgrader] check threw: $e');
    }
  }

  Future<void> _onResult(VersionCheckResult result) async {
    widget.onResult?.call(result);
    var showSoft = false;
    if (widget.options.showSoftPrompt &&
        result.status == UpdateStatus.updateAvailable) {
      final wanted = widget.options.softPromptOnlyBelowRecommended
          ? result.isBelowRecommended
          : true;
      final latest = result.latest;
      if (wanted && latest != null) {
        showSoft = !(await _store?.isSuppressed(latest) ?? false);
      }
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _showSoft = showSoft;
    });
  }

  Future<void> _update() async {
    final r = _result;
    if (r == null) return;
    final handled = await widget.onUpdatePressed?.call(r) ?? false;
    if (handled) return;
    await _manager?.openStoreFor(r);
  }

  Future<void> _later() async {
    widget.onLater?.call();
    await _store?.remindLater(widget.options.remindLaterAfter);
    if (mounted) setState(() => _showSoft = false);
  }

  Future<void> _skip() async {
    final latest = _result?.latest;
    if (latest != null) {
      widget.onSkipped?.call(latest);
      await _store?.skip(latest);
    }
    if (mounted) setState(() => _showSoft = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r == null) return widget.child;

    final blocked =
        r.isBlocked || (widget.options.blockWhenCheckFails && r.isFailed);
    if (blocked) {
      final builder = widget.requiredBuilder;
      if (builder != null) return builder(context, r, _update);
      return UpdateRequiredScreen(
        result: r,
        style: widget.style,
        texts: widget.texts,
        onUpdate: _update,
        onRetry: () => check(),
      );
    }

    if (!_showSoft) return widget.child;

    final builder = widget.availableBuilder;
    final prompt = builder != null
        ? builder(context, r, _update, _later, _skip)
        : UpdateAvailablePrompt(
            result: r,
            style: widget.style,
            texts: widget.texts,
            onUpdate: _update,
            onLater: _later,
            onSkip: widget.options.allowSkipVersion ? _skip : null,
          );

    return Stack(
      children: [
        widget.child,
        if (widget.options.allowLater || builder != null)
          prompt
        else
          // "Later" disabled: keep the barrier tap harmless by routing it to
          // a no-op so the user can still reach the Skip/Update buttons.
          UpdateAvailablePrompt(
            result: r,
            style: widget.style,
            texts: widget.texts.copyWith(laterButton: ''),
            onUpdate: _update,
            onLater: () {},
            onSkip: widget.options.allowSkipVersion ? _skip : null,
          ),
      ],
    );
  }
}
