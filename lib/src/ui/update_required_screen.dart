import 'package:flutter/material.dart';

import '../models/version_check_result.dart';
import 'upgrader_content.dart';
import 'upgrader_style.dart';
import 'upgrader_texts.dart';

/// Full-screen, non-dismissible "update required" page.
///
/// Used by [VersionUpgrader] for `updateRequired` (and for `checkFailed`
/// under a fail-closed policy). Can also be used on its own.
class UpdateRequiredScreen extends StatelessWidget {
  /// Creates the screen.
  const UpdateRequiredScreen({
    super.key,
    required this.result,
    required this.onUpdate,
    this.style = const UpgraderStyle(),
    this.texts = const UpgraderTexts(),
    this.onRetry,
  });

  /// The decision.
  final VersionCheckResult result;

  /// Opens the store.
  final VoidCallback onUpdate;

  /// Visual style.
  final UpgraderStyle style;

  /// Texts.
  final UpgraderTexts texts;

  /// Shown instead of the update button when the check failed and the app is
  /// configured to block (fail-closed).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = style.resolve(context);
    final failed = result.isFailed;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: s.background,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.9),
              radius: 1.2,
              colors: [
                s.accent.withAlpha(
                    (((s.isDark ? 0.26 : 0.16) * 255).round()).clamp(0, 255)),
                s.background.withAlpha((((0) * 255).round()).clamp(0, 255)),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: s.padding,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: UpgraderContent(
                    heroScale: 1.25,
                    result: result,
                    style: s,
                    texts: failed
                        ? texts.copyWith(updateButton: 'Retry', versionLine: '')
                        : texts,
                    title: failed
                        ? 'Unable to verify version'
                        : texts.requiredTitle,
                    message: failed
                        ? 'The version service could not be reached. '
                            'Please check your connection and try again.'
                        : texts.resolveRequiredMessage(result),
                    onUpdate: failed ? (onRetry ?? onUpdate) : onUpdate,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
