import 'package:meta/meta.dart';

import '../models/version_check_result.dart';

/// Every string the built-in UI shows. Override any of them for branding or
/// localisation. Placeholders `{current}`, `{latest}` and `{minimum}` are
/// replaced with the matching versions.
@immutable
class UpgraderTexts {
  /// Creates the texts with English defaults.
  const UpgraderTexts({
    this.requiredTitle = 'Update required',
    this.requiredMessage =
        'This version is no longer supported. Please update to version '
        '{minimum} or newer to continue.',
    this.availableTitle = 'Update available',
    this.availableMessage =
        'Version {latest} is ready. Update now to get the latest '
        'improvements.',
    this.updateButton = 'Update now',
    this.laterButton = 'Later',
    this.skipButton = 'Skip this version',
    this.releaseNotesTitle = "What's new",
    this.versionLine = '',
    this.useServerMessageForSoftPrompt = false,
  });

  /// Title of the blocking screen.
  final String requiredTitle;

  /// Body of the blocking screen when the backend sends no `update_message`.
  final String requiredMessage;

  /// Title of the soft prompt.
  final String availableTitle;

  /// Body of the soft prompt.
  final String availableMessage;

  /// Primary action label.
  final String updateButton;

  /// Dismisses the soft prompt until the next reminder.
  final String laterButton;

  /// Dismisses the soft prompt for this version permanently.
  final String skipButton;

  /// Heading above the release notes, when the backend provides them.
  final String releaseNotesTitle;

  /// Small line under the message; empty (the default) hides it. The version
  /// chips already show installed → latest; use this when
  /// `UpgraderStyle.showVersionChips` is off, e.g.
  /// `'Installed {current} · Latest {latest}'`.
  final String versionLine;

  /// When `true`, the backend's `update_message` (if any) also replaces
  /// [availableMessage]. By default it is only used on the blocking screen,
  /// where admins typically write "please update to continue".
  final bool useServerMessageForSoftPrompt;

  /// Resolves the blocking message for [result].
  String resolveRequiredMessage(VersionCheckResult result) =>
      fill(result.updateMessage ?? requiredMessage, result);

  /// Resolves the soft prompt message for [result].
  String resolveAvailableMessage(VersionCheckResult result) {
    final server = result.updateMessage;
    final template =
        useServerMessageForSoftPrompt && server != null ? server : availableMessage;
    return fill(template, result);
  }

  /// Replaces placeholders in [template] from [result].
  static String fill(String template, VersionCheckResult result) => template
      .replaceAll('{current}', result.current.version.toString())
      .replaceAll('{latest}', result.latest?.version.toString() ?? '')
      .replaceAll('{minimum}', result.minimum?.version.toString() ?? '');

  /// Returns a copy with the given fields replaced.
  UpgraderTexts copyWith({
    String? requiredTitle,
    String? requiredMessage,
    String? availableTitle,
    String? availableMessage,
    String? updateButton,
    String? laterButton,
    String? skipButton,
    String? releaseNotesTitle,
    String? versionLine,
    bool? useServerMessageForSoftPrompt,
  }) =>
      UpgraderTexts(
        requiredTitle: requiredTitle ?? this.requiredTitle,
        requiredMessage: requiredMessage ?? this.requiredMessage,
        availableTitle: availableTitle ?? this.availableTitle,
        availableMessage: availableMessage ?? this.availableMessage,
        updateButton: updateButton ?? this.updateButton,
        laterButton: laterButton ?? this.laterButton,
        skipButton: skipButton ?? this.skipButton,
        releaseNotesTitle: releaseNotesTitle ?? this.releaseNotesTitle,
        versionLine: versionLine ?? this.versionLine,
        useServerMessageForSoftPrompt:
            useServerMessageForSoftPrompt ?? this.useServerMessageForSoftPrompt,
      );
}
